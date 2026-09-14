class SubscriptionChange < ApplicationRecord
  # Business trail of subscription plan changes. A user-visible record (the
  # scheduled downgrade banner reads status: scheduled) and an audit/ops trail
  # (pending -> succeeded / failed) driven by Stripe webhooks.
  #
  # Status flow:
  #   upgrade:  pending -> succeeded | failed          (charge collected now)
  #   downgrade: scheduled -> succeeded (at effective_at / renewal, no charge now)
  CHANGE_TYPES = %w[upgrade downgrade same renewal cancellation checkout].freeze

  belongs_to :user
  belongs_to :user_subscription, optional: true
  belongs_to :from_subscription, class_name: "Subscription", optional: true
  belongs_to :to_subscription, class_name: "Subscription", optional: true

  enum :status, {
    pending: "pending",
    scheduled: "scheduled",
    succeeded: "succeeded",
    failed: "failed",
    reverted: "reverted"
  }

  enum :change_type, {
    upgrade: "upgrade",
    downgrade: "downgrade",
    same: "same",
    renewal: "renewal",
    cancellation: "cancellation",
    checkout: "checkout"
  }

  validates :change_type, inclusion: { in: CHANGE_TYPES }
  validates :idempotency_key, uniqueness: { scope: :user_id }, allow_nil: true
  validates :provider_invoice_id, uniqueness: true, allow_nil: true

  # Scheduled dowgrades that are waiting on the next renewal to take effect.
  scope :scheduled, -> { where(status: :scheduled) }
  # Scheduled downgrades whose effective date has arrived (safe to complete).
  scope :due, -> { scheduled.where("effective_at <= ?", Time.current) }
  scope :pending, -> { where(status: :pending) }

  # The single most relevant "you are changing plans" record for the UI.
  def self.most_recent_for(user)
    user.subscription_changes
        .where(status: [:pending, :scheduled])
        .order(effective_at: :asc, id: :desc)
        .first
  end
end