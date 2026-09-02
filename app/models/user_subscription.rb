class UserSubscription < ApplicationRecord
  belongs_to :user
  belongs_to :subscription

  enum :status, { active: "active", cancelled: "cancelled", expired: "expired", trial: "trial" }

  validates :started_at, presence: true

  scope :current, -> { where(status: :active, ended_at: nil) }
end