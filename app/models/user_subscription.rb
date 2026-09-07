class UserSubscription < ApplicationRecord
  belongs_to :user
  belongs_to :subscription

  enum :status, { active: "active", past_due: "past_due", cancelled: "cancelled", expired: "expired", trial: "trial" }

  validates :started_at, presence: true
  validates :billing_provider, presence: true

  scope :current, -> { where(status: :active, ended_at: nil) }
end