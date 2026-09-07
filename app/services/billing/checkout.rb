module Billing
  class Checkout
    # Create a checkout session for a user purchasing a subscription.
    #
    # @param user [User]
    # @param subscription [Subscription]
    # @return [Hash] { url:, session_id: }
    def self.create(user:, subscription:)
      raise Billing::Error, "Billing is not configured." unless Billing.configured?

      adapter = Billing.adapter
      billing_price = subscription.billing_price_for(adapter.provider_key)
      unless billing_price&.active? && billing_price.amount_cents.to_i.positive?
        raise Billing::Error, "This subscription is not available for online purchase."
      end

      Billing::Customer.ensure!(user)

      base = ENV.fetch("FRONTEND_URL", "http://localhost:5173")
      adapter.create_checkout_session(
        user: user,
        subscription: subscription,
        billing_price: billing_price,
        success_url: "#{base}/subscribe?checkout=success&session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "#{base}/subscribe?checkout=cancelled"
      )
    end
  end
end