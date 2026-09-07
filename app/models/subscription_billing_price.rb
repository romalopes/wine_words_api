class SubscriptionBillingPrice < ApplicationRecord
  # Maps a WinePrediction Subscription to how it is sold through a billing
  # provider (e.g. Stripe). The app's own amount/currency/interval are stored
  # here; provider_product_id / provider_price_id are external integration ids.
  INTERVALS = %w[year month].freeze

  belongs_to :subscription

  # Valid providers come from the Billing registry (Stripe registers itself, and
  # future providers do the same) so new providers need no model change.
  validates :provider, inclusion: { in: -> { Billing::Providers.registry.keys.map(&:to_s) } }
  validates :billing_interval, inclusion: { in: INTERVALS }
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :provider_price_id, uniqueness: { scope: :provider }
  validates :provider, uniqueness: { scope: :subscription_id }

  scope :active, -> { where(active: true) }
  scope :for_provider, ->(provider) { where(provider: provider) }
end