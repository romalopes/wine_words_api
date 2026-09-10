# Stripe billing provider adapter.
#
# All Stripe-specific knowledge lives here: product/price/customer/checkout/
# portal session creation and the mapping of Stripe subscription statuses to
# the application's status vocabulary. Nothing outside this file references
# the Stripe gem or Stripe ids.
module Billing
  module Providers
    class Stripe < Base
      def provider_key
        :stripe
      end

      def self.configured?
        ENV["STRIPE_SECRET_KEY"].present?
      end

      def ensure_customer(user)
        customer = ::Stripe::Customer.create(
          email: user.email,
          name: user.user_name,
          metadata: { user_id: user.id }
        )
        { id: customer.id }
      end

      def create_checkout_session(user:, subscription:, billing_price:, success_url:, cancel_url:)
        # Reuse the app's Stripe customer so webhook events (which carry the
        # customer id) map back to the user. Passing only customer_email would
        # make Stripe create a NEW customer on every checkout.
        customer = Billing::Customer.ensure!(user)

        session = ::Stripe::Checkout::Session.create(
          mode: "subscription",
          customer: customer.provider_customer_id,
          line_items: [{
            price: billing_price.provider_price_id,
            quantity: 1
          }],
          success_url: success_url,
          cancel_url: cancel_url,
          metadata: {
            subscription_id: subscription.id,
            billing_price_id: billing_price.id
          }
        )
        { url: session.url, session_id: session.id }
      end

      def create_portal_session(user:, return_url:)
        customer = Billing::Customer.ensure!(user)
        raise Billing::Error, "No billing customer to open a portal." if customer.nil?

        session = ::Stripe::BillingPortal::Session.create(
          customer: customer.provider_customer_id,
          return_url: return_url
        )
        { url: session.url }
      end

      # Build { user:, subscription:, plan:, status:, provider_subscription_id:,
      #       billing_price: } from a Stripe subscription object payload.
      def build_subscription_from_event(payload)
        customer_id = payload.dig("customer")
        sub_id = payload.dig("id")

        billing_customer = BillingCustomer.find_by(provider: "stripe", provider_customer_id: customer_id)
        return nil if billing_customer.blank?

        plan = payload.dig("plan")
        billing_price = nil
        item = payload.dig("items", "data", 0)
        if item
          price_id = item.dig("price", "id")
          billing_price = SubscriptionBillingPrice.active.for_provider(:stripe).find_by(provider_price_id: price_id)
        end

        {
          user: billing_customer.user,
          subscription: billing_price&.subscription,
          plan: plan,
          status: map_status(payload.dig("status")),
          provider_subscription_id: sub_id,
          billing_price: billing_price
        }
      end

      # Stripe subscription statuses -> app vocabulary.
      def map_status(provider_status)
        case provider_status
        when "active", "trialing" then "active"
        when "past_due", "unpaid", "incomplete", "incomplete_expired" then "past_due"
        when "canceled" then "cancelled"
        when "paused" then "paused"
        else "expired"
        end
      end

      def self.verify_webhook(payload, signature)
        Rails.logger.info "[Stripe Webhook] verify_webhook: payload size #{payload.bytesize} bytes, signature present: #{signature.present?}"
        api_event = ::Stripe::Webhook.construct_event(
          payload,
          signature,
          ENV.fetch("STRIPE_WEBHOOK_SECRET")
        )
        Rails.logger.info "[Stripe Webhook] verify_webhook: event=#{api_event.id} type=#{api_event.type}"
        api_event
      end
    end
  end
end

Billing::Providers.register(Billing::Providers::Stripe)