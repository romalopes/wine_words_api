module Billing
  class Subscription
    # Apply a provider subscription to a user via the existing business logic.
    #
    # @param user [User]
    # @param subscription [Subscription] the WinePrediction plan
    # @param billing_provider [String]
    # @param provider_subscription_id [String]
    # @param allow_downgrade [Boolean] when true, bypass the downgrade check
    # @return [void]
    def self.apply(user:, subscription:, billing_provider:, provider_subscription_id:, allow_downgrade: false)
      user.apply_subscription!(
        subscription,
        billing_provider: billing_provider,
        provider_subscription_id: provider_subscription_id,
        allow_downgrade: allow_downgrade
      )
    end
  end
end
