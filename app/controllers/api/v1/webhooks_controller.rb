class Api::V1::WebhooksController < ActionController::Base
  # POST /api/v1/webhooks/stripe
  # Receives Stripe webhook events. Authentication is via the webhook signature
  # (Stripe::Webhook.construct_event), not the JWT bearer token, so we skip
  # the ApplicationController's authenticate_user! and forgery protection.
  skip_forgery_protection
  before_action :verify_stripe_webhook

  def stripe
    # Parse the verified event.
    event = @stripe_event

    # Idempotent processing: claim the event so it's only processed once.
    claimed = BillingEvent.claim(
      provider: "stripe",
      provider_event_id: event.id,
      event_type: event.type,
      payload: event.to_hash
    )

    # If the event was already processed, acknowledge it silently (Stripe expects 200).
    if claimed.nil?
      head :ok
      return
    end

    # Dispatch to the appropriate handler based on event type.
    # Supported events are expanded incrementally as needed (Stage E).
    # NOTE: event.data.object is a Stripe::StripeObject. Convert it to a plain
    # string-keyed hash (to_hash returns symbol keys and nested StripeObjects)
    # so handlers can use string-keyed dig/[] freely.
    case event.type
    when "checkout.session.completed"
      handle_checkout_completed(event.data.object.to_hash.deep_stringify_keys)
    when "customer.subscription.created", "customer.subscription.updated"
      handle_subscription_change(event.data.object.to_hash.deep_stringify_keys)
    when "customer.subscription.deleted"
      handle_subscription_cancelled(event.data.object.to_hash.deep_stringify_keys)
    when "invoice.paid"
      handle_invoice_paid(event.data.object.to_hash.deep_stringify_keys)
    when "invoice.payment_failed"
      handle_payment_failed(event.data.object.to_hash.deep_stringify_keys)
    else
      # Unrecognised events are still acknowledged (return 200).
      Rails.logger.info "[Stripe Webhook] Unhandled event type: #{event.type} (#{event.id})"
    end

    head :ok
  rescue Billing::Error => e
    Rails.logger.error "[Stripe Webhook] Processing error: #{e.message}"
    head :ok # Never return non-200 to Stripe; they'll retry.
  rescue => e
    Rails.logger.error "[Stripe Webhook] Unexpected error: #{e.message}"
    head :ok
  end

  private

  def verify_stripe_webhook
    payload = request.body.read
    sig_header = request.headers["HTTP_STRIPE_SIGNATURE"] || request.headers["Stripe-Signature"]

    @stripe_event = Billing::Providers::Stripe.verify_webhook(payload, sig_header)
  rescue Stripe::SignatureVerificationError => e
    Rails.logger.error "[Stripe Webhook] Signature verification failed: #{e.message}"
    head :bad_request
  end

  # ── Event handlers (filled out in Stage E) ──────────────────────────────

  def handle_checkout_completed(checkout_session)
    # A checkout completed successfully. The subscription was created by
    # Stripe; we record it against the user and activate the plan directly
    # from the session metadata (robust even if the customer mapping is
    # out of sync).
    provider_sub_id = checkout_session["subscription"]
    return if provider_sub_id.nil?

    customer_id = checkout_session["customer"]
    metadata = checkout_session["metadata"] || {}
    billing_price_id = metadata["billing_price_id"]
    billing_price = billing_price_id.present? ? SubscriptionBillingPrice.find_by(id: billing_price_id) : nil
    return if billing_price.nil?

    # Map the Stripe customer used at checkout back to the user, creating or
    # correcting the mapping if needed (e.g. checkouts made before the
    # session passed `customer:`).
    billing_customer = BillingCustomer.find_by(provider: "stripe", provider_customer_id: customer_id)
    if billing_customer.nil?
      email = checkout_session.dig("customer_details", "email")
      user = email && User.find_by(email: email)
      user ||= billing_price.subscription.user_subscriptions.current.first&.user
      return if user.nil?

      billing_customer = BillingCustomer.find_or_create_by!(
        user: user,
        provider: "stripe"
      ) { |bc| bc.provider_customer_id = customer_id }
      billing_customer.update!(provider_customer_id: customer_id) if billing_customer.provider_customer_id != customer_id
    end

    Rails.logger.info(
      "[Stripe Webhook] Checkout completed: customer=#{customer_id} subscription=#{provider_sub_id} " \
      "user=#{billing_customer.user_id} price=#{billing_price.id}"
    )

    Billing::Subscription.apply(
      user: billing_customer.user,
      subscription: billing_price.subscription,
      billing_provider: "stripe",
      provider_subscription_id: provider_sub_id
    )
  end

  def handle_subscription_change(subscription_data)
    adapter = Billing::Providers::Stripe.new
    result = adapter.build_subscription_from_event(subscription_data)
    return if result.nil?

    status = result[:status]
    user = result[:user]
    plan = result[:subscription]

    case status
    when "active"
      Billing::Subscription.apply(
        user: user,
        subscription: plan,
        billing_provider: "stripe",
        provider_subscription_id: result[:provider_subscription_id]
      )
    when "past_due"
      # Mark the user's subscription as past_due if needed.
      current = user.user_subscriptions.current.first
      current&.update!(status: :past_due)
    end
  end

  def handle_subscription_cancelled(subscription_data)
    adapter = Billing::Providers::Stripe.new
    result = adapter.build_subscription_from_event(subscription_data)
    return if result.nil?

    user = result[:user]
    current = user.user_subscriptions.current.first
    return if current.nil?

    current.update!(
      status: :cancelled,
      cancelled_at: Time.current,
      ended_at: Time.current
    )

    # Fall back to the default FREE plan.
    free_plan = Subscription.find_by(is_default: true) || Subscription.find_by!(slug: "free")
    user.apply_subscription!(free_plan)
  end

  def handle_invoice_paid(invoice)
    # The subscription is still active — nothing extra needed beyond the
    # subscription.updated event that Stripe also sends.
    Rails.logger.info "[Stripe Webhook] Invoice paid: #{invoice['id']}"
  end

  def handle_payment_failed(invoice)
    subscription_id = invoice["subscription"]
    return if subscription_id.nil?

    user_sub = UserSubscription.find_by(
      billing_provider: "stripe",
      provider_subscription_id: subscription_id
    )
    return if user_sub.nil?

    user_sub.update!(status: :past_due)
    Rails.logger.warn "[Stripe Webhook] Payment failed for subscription #{subscription_id}"
  end
end