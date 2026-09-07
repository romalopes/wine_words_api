module Billing
  class Customer
    # Find or create the user's billing customer for the active provider.
    # Returns nil when billing is not fully configured (manual/none).
    def self.ensure!(user)
      return nil unless Billing.configured?

      adapter = Billing.adapter
      customer = user.billing_customers.find_by(provider: adapter.provider_key.to_s)
      return customer if customer

      provider_customer = adapter.ensure_customer(user)
      user.billing_customers.create!(
        provider: adapter.provider_key.to_s,
        provider_customer_id: provider_customer[:id]
      )
    rescue StandardError => e
      raise Billing::Error, "Could not create billing customer: #{e.message}"
    end
  end
end