module Billing
  class ConfirmCheckout
    # Reconcile a Stripe Checkout Session for the current user.
    #
    # @param user [User] the authenticated user returning from Stripe
    # @param session_id [String] the Stripe Checkout Session id (cs_...)
    # @return [Hash] { applied:, session_id:, payment_status:, status:,
    #   subscription_id:, provider_subscription_id: }
    #
    # Raises Billing::Error when the session is invalid, unpaid, or belongs
    # to a different billing customer.
    def self.call(user:, session_id:)
      raise Billing::Error, "Billing is not configured." unless Billing.stripe_enabled?

      adapter = Billing.adapter
      raise Billing::Error, "Billing is not configured." unless adapter.provider_key == :stripe

      begin
        session = ::Stripe::Checkout::Session.retrieve(session_id)
      rescue ::Stripe::StripeError => e
        raise Billing::Error, "Could not verify checkout session: #{e.message}"
      end

      session_customer_id = session.customer
      session_payment = session.payment_status
      session_status = session.status
      provider_sub_id = session.subscription

      billing_customer = user.billing_customers.find_by(provider: "stripe")

      unless billing_customer && session_customer_id.present? &&
             billing_customer.provider_customer_id == session_customer_id
        raise Billing::Error, "This checkout session does not belong to your account."
      end

      unless session_payment == "paid" && session_status == "complete"
        return {
          applied: false,
          session_id: session_id,
          payment_status: session_payment,
          status: session_status,
          subscription_id: nil,
          provider_subscription_id: provider_sub_id
        }
      end

      plan, billing_price = resolve_plan(session, provider_sub_id)
      unless plan
        raise Billing::Error, "Could not determine the purchased plan for this session."
      end

      # Idempotency: if a current row already points at this provider
      # subscription, there is nothing left to do (webhook may have beaten us).
      if provider_sub_id.present?
        existing = user.user_subscriptions.current.find_by(
          billing_provider: "stripe",
          provider_subscription_id: provider_sub_id
        )
        if existing
          return {
            applied: true,
            session_id: session_id,
            payment_status: session_payment,
            status: existing.status,
            subscription_id: existing.subscription_id,
            provider_subscription_id: provider_sub_id,
            already_applied: true
          }
        end
      end

      Billing::Subscription.apply(
        user: user,
        subscription: plan,
        billing_provider: "stripe",
        provider_subscription_id: provider_sub_id
      )

      {
        applied: true,
        session_id: session_id,
        payment_status: session_payment,
        status: "active",
        subscription_id: plan.id,
        provider_subscription_id: provider_sub_id,
        already_applied: false
      }
    end

    # Resolve the purchased WinePrediction plan for a checkout session.
    # Prefers the session metadata (written at checkout creation); falls back
    # to the Stripe Price on the underlying subscription (DB-id independent,
    # so it works across local/Neon databases).
    def self.resolve_plan(session, provider_sub_id)
      metadata = session.metadata.to_h
      subscription_id = metadata["subscription_id"] || metadata[:subscription_id]
      billing_price_id = metadata["billing_price_id"] || metadata[:billing_price_id]

      plan = ::Subscription.find_by(id: subscription_id) if subscription_id.present?
      billing_price = SubscriptionBillingPrice.find_by(id: billing_price_id) if billing_price_id.present?
      return [plan || billing_price&.subscription, billing_price] if plan || billing_price

      price_id = nil
      if provider_sub_id.present?
        begin
          provider_sub = ::Stripe::Subscription.retrieve(provider_sub_id)
          price_id = provider_sub.dig("items", "data", 0, "price", "id")
        rescue ::Stripe::StripeError
          price_id = nil
        end
      end

      if price_id.present?
        billing_price = SubscriptionBillingPrice.active.for_provider(:stripe).find_by(provider_price_id: price_id)
        return [billing_price&.subscription, billing_price] if billing_price
      end

      [nil, nil]
    end
    private_class_method :resolve_plan
  end
end
