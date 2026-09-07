class BillingCustomer < ApplicationRecord
  # A user's identity with a billing provider. A user may have one record per
  # provider; provider customer ids are unique per provider.
  belongs_to :user

  # Valid providers come from the Billing registry (Stripe registers itself, and
  # future providers do the same) so new providers need no model change.
  validates :provider, inclusion: { in: -> { Billing::Providers.registry.keys.map(&:to_s) } }
  validates :provider_customer_id, presence: true,
                                   uniqueness: { scope: :provider }
  validates :provider, uniqueness: { scope: :user_id }
end