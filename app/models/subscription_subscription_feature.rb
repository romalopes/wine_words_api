class SubscriptionSubscriptionFeature < ApplicationRecord
  belongs_to :subscription
  belongs_to :subscription_feature

  validates :subscription_feature_id, uniqueness: { scope: :subscription_id }
end