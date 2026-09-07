module Billing
  class Subscription
    # Apply a provider subscription to a user via the existing business logic.
    #
    # @param user [User]
    # @param subscription [Subscription] the WinePrediction plan
    # @param billing_provider [String]
    # @param provider_subscription_id [String]
    # @return [void]
    def self.apply(user:, subscription:, billing_provider:, provider_subscription_id:)
      user.apply_subscription!(
        subscription,
        billing_provider: billing_provider,
        provider_subscription_id: provider_subscription_id
      )
    end
  end
end