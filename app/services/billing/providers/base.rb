# Contract/canary for a billing provider. Concrete providers (Stripe, future
# PayPal/Square/Adyen) implement these methods. The rest of the app depends on
# this interface, never on provider internals.
module Billing
  module Providers
    class Base
      # @return [Symbol] provider key, e.g. :stripe
      def provider_key
        raise NotImplementedError
      end

      # Ensure a billing customer exists for the user on this provider and
      # return the provider-side customer object/id.
      def ensure_customer(user)
        raise NotImplementedError
      end

      # Create a checkout session for purchasing the given subscription for the
      # given user. Returns a struct/hash with :url and :session_id.
      def create_checkout_session(user:, subscription:, billing_price:, success_url:, cancel_url:)
        raise NotImplementedError
      end

      # Create a customer portal session; returns a hash with :url.
      def create_portal_session(user:, return_url:)
        raise NotImplementedError
      end

      # Preview a subscription plan change (upgrade or downgrade). Stripe
      # calculates the proration; returns a hash with :direction, :due_today_cents,
      # :currency, :next_renewal_cents, :next_renewal_at, :provider_subscription_id.
      def preview_change(user:, target_subscription:)
        raise NotImplementedError
      end

      # Apply a subscription plan change. mode is :upgrade (prorated charge now,
      # effect immediately) or :downgrade (effective at the next renewal, no
      # charge/refund now). Returns a hash with :mode, :provider_subscription_id,
      # and :effective_at for downgrades.
      def change_subscription(user:, target_subscription:, mode:)
        raise NotImplementedError
      end

      # Build a provider subscription from a webhook event payload.
      def build_subscription_from_event(payload)
        raise NotImplementedError
      end

      # Map a provider subscription status to the app's status vocabulary.
      def map_status(provider_status)
        raise NotImplementedError
      end

      # Whether this provider is configured (credentials present).
      def self.configured?
        raise NotImplementedError
      end
    end
  end
end