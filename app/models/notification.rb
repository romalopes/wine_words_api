# One notification event, shared by email delivery and a future in-app list.
#
# Wine-package deadline reminders are the first type, but the model is generic:
# a recipient, a type, and an optional polymorphic `notifiable`.
#
# Idempotency: the unique index on
#   (wine_package_id, notification_type, scheduled_date)
# guarantees a given reminder for a given package/type/day can only exist once,
# so the scheduling job can run as often as it likes without spamming.
# Note the index only guards package-scoped notifications (NULLs are distinct
# in PostgreSQL); generic notifications without a package are not de-duplicated.
class Notification < ApplicationRecord
  TYPES = %w[
    wine_package_deadline
    wine_package_arrived
    wine_package_completed
    wine_package_rejected
  ].freeze

  belongs_to :recipient, class_name: "User"
  belongs_to :notifiable, polymorphic: true, optional: true
  belongs_to :wine_package, optional: true

  validates :notification_type, presence: true, inclusion: { in: TYPES }

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :delivered, -> { where.not(sent_at: nil) }
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

  def mark_read!(at: Time.current)
    return self if read_at.present?

    update!(read_at: at)
  end

  def mark_sent!(at: Time.current)
    return self if sent_at.present?

    update!(sent_at: at)
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
