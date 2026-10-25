# frozen_string_literal: true

# Publishes a domain event for the follow-notification pipeline (issue #192).
#
# Usage (typically after_save / after_commit in controllers or models):
#
#   Notifications::EventPublisher.publish!(
#     event_type: "review.published",
#     subject: review,
#     actor: current_user,
#     metadata: { title: review.title }
#   )
#
# Idempotency: a deterministic key is used for state-changing events
# (publication, comment, creation) so repeating the callback can never create a
# duplicate event; `updated` events use a random key because every meaningful
# edit is its own event. The unique index on idempotency_key is the DB guard.
#
# Reliability: the event is persisted first (outbox) and processing is enqueued
# after creation; Notifications::RecoveryJob re-processes events whose enqueue
# or worker run was lost.
module Notifications
  class EventPublisher
    # Deterministic keys: one event per logical occurrence.
    DETERMINISTIC = %w[published comment_created created].freeze

    class << self
      def publish!(event_type:, subject:, actor: nil, metadata: {}, idempotency_key: nil)
        return nil unless AppSetting.follow_notifications_enabled?

        key = idempotency_key || default_key(event_type, subject)

        targets = AffectedTargetsResolver.new(subject).resolve

        event = NotificationEvent.create!(
          event_type: event_type,
          subject_type: subject.class.name,
          subject_id: subject.id,
          actor_id: actor&.id,
          occurred_at: Time.current,
          affected_targets: targets,
          metadata: safe_metadata(subject, metadata),
          idempotency_key: key
        )

        Notifications::ProcessEventJob.perform_later(event.id)
        event
      rescue ActiveRecord::RecordNotUnique
        # Another invocation of the same logical event won the race (DB index).
        NotificationEvent.find_by!(idempotency_key: key)
      rescue ActiveRecord::RecordInvalid => e
        # The uniqueness VALIDATION can fire before the DB index does; treat it
        # as the same idempotent case. Other validation errors re-raise.
        existing = NotificationEvent.find_by(idempotency_key: key)
        raise e if existing.nil?

        existing
      end

      private

      def default_key(event_type, subject)
        occurrence = event_type.split(".").last
        if DETERMINISTIC.include?(occurrence)
          "#{event_type}.#{subject.class.name}.#{subject.id}"
        else
          "#{event_type}.#{subject.class.name}.#{subject.id}.#{SecureRandom.hex(8)}"
        end
      end

      # Only safe display data (names/titles/slugs) ever lands in metadata —
      # never comment bodies or full article text.
      def safe_metadata(subject, extra)
        base =
          case subject
          when Review
            { subject_label: subject.title, subject_slug: subject.slug }
          when Article
            { subject_label: subject.title, subject_slug: subject.slug }
          when Wine
            { subject_label: subject.name, subject_slug: subject.slug }
          when Vintage
            { subject_label: subject.year.to_s, subject_slug: nil }
          when Producer
            { subject_label: subject.name, subject_slug: subject.slug }
          end || {}

        base.merge(extra.transform_keys(&:to_sym))
      end
    end
  end
end