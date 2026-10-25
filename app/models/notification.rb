# One notification delivery, shared by email delivery and the in-app list.
#
# Two row kinds share this table:
#
# 1. Wine-package deadline reminders: tied to wine_package_id + type +
#    scheduled_date; `sent_at` is the email channel; visible in the app once
#    `delivered_at` is stamped (backfilled = sent_at for legacy rows).
#
# 2. Follow-based deliveries (issue #192): tied to a `notification_event` via
#    notification_event_id. `delivered_at` is stamped when the delivery is
#    created (in-app only); `sent_at` stays NULL unless a later phase emails it.
#    The partial unique index on (recipient_id, notification_event_id) makes
#    one-delivery-per-recipient-per-event a database guarantee.
#
# Idempotency for kind 1: the unique index on
#   (wine_package_id, notification_type, scheduled_date)
# guarantees a given reminder for a given package/type/day can only exist once.
# Note the index only guards package-scoped notifications (NULLs are distinct
# in PostgreSQL); generic notifications without a package are not de-duplicated
# by it.
class Notification < ApplicationRecord
  TYPES = %w[
    wine_package_deadline
    wine_package_arrived
    wine_package_completed
    wine_package_rejected
    review_published
    review_updated
    review_comment
    article_published
    article_updated
    article_comment
    wine_created
    wine_updated
    vintage_created
    vintage_updated
    producer_updated
  ].freeze

  belongs_to :recipient, class_name: "User"
  belongs_to :notifiable, polymorphic: true, optional: true
  belongs_to :wine_package, optional: true
  belongs_to :notification_event, optional: true
  belongs_to :actor, class_name: "User", optional: true

  validates :notification_type, presence: true, inclusion: { in: TYPES }

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  # In-app visibility: a row is in the feed once EITHER channel happened —
  # package reminders are delivered when their email is sent (sent_at), while
  # follow notifications (issue #192) are delivered in-app only (delivered_at).
  scope :delivered, -> { where.not(delivered_at: nil).or(where.not(sent_at: nil)) }
  # The email-channel queue: rows awaiting their email. Package reminders only
  # (follow rows are never emailed in this phase and have sent_at = NULL, but
  # the deadline job also filters by its own notification_type).
  scope :undelivered, -> { where(sent_at: nil) }
  scope :for_date, ->(date) { where(scheduled_date: date) }
  scope :by_recency, -> { order(created_at: :desc) }

  before_validation :default_scheduled_date

  def read?
    read_at.present?
  end

  def sent?
    sent_at.present?
  end

  def delivered?
    delivered_at.present?
  end

  def failed?
    failed_at.present?
  end

  def mark_read!(at: Time.current)
    return self if read_at.present?

    update!(read_at: at)
  end

  def mark_sent!(at: Time.current)
    return self if sent_at.present? && failed_at.nil?

    update!(sent_at: sent_at || at, failed_at: nil)
  end

  def mark_failed!(at: Time.current)
    update!(failed_at: at)
  end

  def mark_delivered!(at: Time.current)
    return self if delivered_at.present?

    update!(delivered_at: at)
  end

  # Idempotent factory. The dedup key is
  # (wine_package, notification_type, scheduled_date): a package can only have
  # one reminder of a given type for a given day, no matter how often the
  # scheduler runs. The recipient is recorded when the reminder is created
  # (packages have one responsible reviewer), so a later call with a different
  # recipient reuses — rather than duplicates — the existing reminder.
  def self.notify!(recipient:, type:, notifiable: nil, wine_package: nil,
                   scheduled_date: Date.current, message: nil)
    identity = {
      notification_type: type.to_s,
      wine_package: wine_package,
      scheduled_date: scheduled_date
    }

    # Deliberately not find_or_create_by!: on a unique-index conflict Rails
    # retries the lookup with the FULL attribute set (including recipient), which
    # cannot match a reminder created for somebody else. Looking the row up by
    # its dedup key keeps the call idempotent no matter who asks.
    existing = find_by(identity)
    return existing if existing

    create!(identity.merge(recipient: recipient, notifiable: notifiable, message: message))
  rescue ActiveRecord::RecordNotUnique
    # Lost a race with a concurrent scheduler run: return the row that won.
    find_by(identity) || raise
  end

  private

  def default_scheduled_date
    self.scheduled_date ||= Date.current
  end
end
