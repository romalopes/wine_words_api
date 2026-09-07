module Billing
  class Portal
    # Create a customer portal session for the user. Returns { url: } or nil
    # if billing isn't configured / the user has no provider customer.
    def self.create(user:)
      return nil unless Billing.configured?

      adapter = Billing.adapter
      customer = user.billing_customers.find_by(provider: adapter.provider_key.to_s)
      return nil unless customer

      base = ENV.fetch("FRONTEND_URL", "http://localhost:5173")
      adapter.create_portal_session(user: user, return_url: "#{base}/subscribe")
    end
  end
end