# Per-user notification preferences (issue #192 phase 8): how the user wants
# follow-based events delivered. One row per user (unique index), created
# lazily with the defaults below — in-app yes, email no, no digest.
#
#   follow_in_app  — keep getting follow events in the notifications feed
#   follow_email   — email each follow event as it happens
#   digest_cadence — none | daily | weekly; when set, undelivered-by-email
#                    follow events are grouped into one digest email per
#                    period (see Notifications::DigestJob)
class NotificationPreference < ApplicationRecord
  CADENCES = %w[none daily weekly].freeze

  belongs_to :user

  validates :digest_cadence, presence: true, inclusion: { in: CADENCES }

  # Singleton-per-user accessor with the safe defaults; safe against races via
  # find_or_create_by! + the unique index.
  def self.for(user)
    user.notification_preference || begin
      find_or_create_by!(user: user)
    rescue ActiveRecord::RecordNotUnique
      find_by!(user: user)
    end
  end

  def digest?
    digest_cadence != "none"
  end

  def as_json
    {
      follow_in_app: follow_in_app,
      follow_email: follow_email,
      digest_cadence: digest_cadence,
      digest_last_sent_at: digest_last_sent_at&.iso8601
    }
  end
end