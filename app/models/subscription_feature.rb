class SubscriptionFeature < ApplicationRecord
  has_many :subscription_subscription_features, dependent: :destroy
  has_many :subscriptions, through: :subscription_subscription_features

  validates :name, :slug, presence: true, uniqueness: true
end