# frozen_string_literal: true

# Turns one NotificationEvent into per-recipient Notification rows.
#
# Contract:
#   * recipients come from FollowerResolver (followers at event time, actor
#     excluded, deduplicated);
#   * the subject's public visibility is rechecked at delivery time — an event
#     whose subject was unpublished/deleted in the meantime is skipped;
#   * one notification per (recipient, event) is a database guarantee via the
#     partial unique index, so insert_all conflicts are ignored;
#   * rows are created already `delivered` (in-app); `sent_at` stays NULL
#     because follow notifications are in-app only in this phase.
module Notifications
  class DeliveryService
    NOTIFICATION_TYPES = {
      "review.published" => "review_published",
      "review.updated" => "review_updated",
      "review.comment_created" => "review_comment",
      "article.published" => "article_published",
      "article.updated" => "article_updated",
      "article.comment_created" => "article_comment",
      "wine.created" => "wine_created",
      "wine.updated" => "wine_updated",
      "vintage.created" => "vintage_created",
      "vintage.updated" => "vintage_updated",
      "producer.updated" => "producer_updated"
    }.freeze

    def initialize(event)
      @event = event
    end

    # Returns the number of deliveries actually inserted.
    def deliver
      return 0 unless Notifications::Visibility.visible?(subject)

      recipients = eligible_recipients
      return 0 if recipients.empty?

      now = Time.current
      rows = recipients.map { |recipient_id| delivery_row(recipient_id, now) }

      inserted = 0
      rows.each_slice(500) do |slice|
        # unique_by: the (recipient, event) partial unique index — ON CONFLICT
        # DO NOTHING, so reprocessing an event (retries) never duplicates.
        result = Notification.insert_all(
          slice,
          returning: %w[id],
          unique_by: :index_notifications_on_recipient_and_event
        )
        inserted += result.length
      end
      log_delivery(recipients.size, inserted)
      inserted
    end

    private

    def subject
      @subject ||= @event.subject
    end

    # Followers of the event's targets who have not turned in-app follow
    # notifications off (phase 8 preferences). One batched query via the
    # follower resolver, then preferences filtered with a single indexed query.
    def eligible_recipients
      candidates = Notifications::FollowerResolver.new(@event).resolve
      return [] if candidates.empty?

      muted = NotificationPreference.where(user_id: candidates, follow_in_app: false)
                                    .pluck(:user_id)
      candidates - muted
    end

    def delivery_row(recipient_id, now)
      {
        recipient_id: recipient_id,
        notification_type: NOTIFICATION_TYPES.fetch(@event.event_type, @event.event_type.tr(".", "_")),
        message: message,
        notification_event_id: @event.id,
        actor_id: @event.actor_id,
        notifiable_type: subject&.class&.name,
        notifiable_id: subject&.id,
        target_path: target_path,
        target_label: @event.metadata["subject_label"],
        delivered_at: now,
        scheduled_date: @event.occurred_at.to_date,
        created_at: now,
        updated_at: now
      }
    end

    def message
      occurrence = @event.event_type.split(".").last
      label = @event.metadata["subject_label"].to_s

      case occurrence
      when "published" then "#{@event.subject_type} published: #{label}"
      when "created" then "#{@event.subject_type} created: #{label}"
      when "updated" then "#{@event.subject_type} updated: #{label}"
      when "comment_created" then "New comment on #{@event.subject_type.downcase}: #{label}"
      else "#{@event.subject_type}: #{label}"
      end
    end

    def target_path
      slug = @event.metadata["subject_slug"]
      base = @event.subject_type.downcase.pluralize
      slug.present? ? "/#{base}/#{slug}" : nil
    end

    def log_delivery(candidates, inserted)
      Rails.logger.info(
        "[Notifications] event=#{@event.id} type=#{@event.event_type} " \
        "candidates=#{candidates} inserted=#{inserted}"
      )
    end
  end
end