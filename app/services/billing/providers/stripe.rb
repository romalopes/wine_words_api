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

      # Preview a subscription plan change. Delegates the proration arithmetic to
      # Stripe (Stripe::Invoice.upcoming) — never reproduced in Rails.
      #
      # @return [Hash] direction (upgrade|downgrade|same), due_today_cents,
      #   currency, next_renewal_cents, next_renewal_at,
      #   provider_subscription_id, current_period_end.
      def preview_change(user:, target_subscription:)
        provider_sub = current_subscription(user)
        raise Billing::Error, "No active Stripe subscription to change." if provider_sub.nil?

        item = provider_sub.items.data[0]
        target_price = target_subscription.billing_price_for("stripe")
        if target_price.nil? || target_price.provider_price_id.blank?
          raise Billing::Error, "This subscription has no Stripe price to change to."
        end

        direction =
          if target_subscription.higher_rank_than?(user.subscription)
            "upgrade"
          elsif target_subscription.lower_rank_than?(user.subscription)
            "downgrade"
          else
            "same"
          end

        upcoming = ::Stripe::Invoice.upcoming(
          customer: provider_sub.customer,
          subscription: provider_sub.id,
          subscription_items: [
            { id: item.id, price: target_price.provider_price_id, quantity: item.quantity || 1 }
          ]
        )

        amount_due = upcoming.amount_due.to_i
        # Downgrades produce a credit (negative amount) that is applied to the
        # next invoice; nothing is collected today per product rules.
        due_today = direction == "downgrade" ? 0 : amount_due.abs

        {
          direction: direction,
          currency: upcoming.currency,
          due_today_cents: due_today,
          next_renewal_cents: target_price.amount_cents.to_i,
          next_renewal_at: epoch_time(provider_sub.current_period_end),
          current_period_end: epoch_time(provider_sub.current_period_end),
          provider_subscription_id: provider_sub.id
        }
      end

      # Apply a subscription plan change.
      #
      # upgrade  -> Stripe::Subscription.update with prorations; Stripe charges
      #             the difference now via the resulting invoice. Same billing
      #             anchor is kept (only the price/item changes).
      # downgrade-> Keep the current plan until the next renewal using a
      #             Stripe SubscriptionSchedule (no refund, no charge now).
      #
      # @return [Hash] mode, provider_subscription_id, effective_at (downgrade).
      def change_subscription(user:, target_subscription:, mode:)
        provider_sub = current_subscription(user)
        raise Billing::Error, "No active Stripe subscription to change." if provider_sub.nil?

        item = provider_sub.items.data[0]
        target_price = target_subscription.billing_price_for("stripe")
        if target_price.nil? || target_price.provider_price_id.blank?
          raise Billing::Error, "This subscription has no Stripe price to change to."
        end

        current_price_id = item.price.id
        quantity = item.quantity || 1

        if mode == :upgrade
          ::Stripe::Subscription.update(
            provider_sub.id,
            items: [{ id: item.id, price: target_price.provider_price_id }],
            proration_behavior: "create_prorations",
            payment_behavior: "default_incomplete",
            metadata: {
              from_subscription_id: user.subscription_id,
              to_subscription_id: target_subscription.id,
              change_type: "upgrade"
            }
          )
          { mode: "upgrade", provider_subscription_id: provider_sub.id }
        else
          # Phase 1 = current price for one billing cycle (finish the period),
          # phase 2 = the lower price indefinitely from the next renewal.
          schedule = ::Stripe::SubscriptionSchedule.create(from_subscription: provider_sub.id)
          ::Stripe::SubscriptionSchedule.update(
            schedule.id,
            phases: [
              { items: [{ price: current_price_id, quantity: quantity }], iterations: 1 },
              { items: [{ price: target_price.provider_price_id, quantity: 1 }] }
            ]
          )
          {
            mode: "downgrade",
            provider_subscription_id: provider_sub.id,
            effective_at: epoch_time(provider_sub.current_period_end)
          }
        end
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
          current_period_start: period_ts(payload.dig("current_period_start"), item&.dig("current_period_start")),
          current_period_end: period_ts(payload.dig("current_period_end"), item&.dig("current_period_end")),
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

      private

      # The user's current Stripe subscription object (or nil when there is no
      # active provider subscription to change).
      def current_subscription(user)
        user_sub = user.user_subscriptions.current
                          .where(billing_provider: "stripe")
                          .where.not(provider_subscription_id: nil)
                          .first
        return nil if user_sub.nil?

        ::Stripe::Subscription.retrieve(user_sub.provider_subscription_id)
      end

      # Convert a Stripe epoch-seconds value to a Time, tolerating nil/0.
      def epoch_time(epoch)
        value = epoch.to_i
        return nil if value.zero?

        Time.at(value)
      end

      # Convert an epoch to a Time, falling back to the secondary value.
      def period_ts(primary, secondary)
        epoch_time(primary) || epoch_time(secondary)
      end
    end
  end
end

Billing::Providers.register(Billing::Providers::Stripe)