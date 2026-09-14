class Api::V1::WebhooksController < ActionController::Base
  # POST /api/v1/webhooks/stripe
  # Receives Stripe webhook events. Authentication is via the webhook signature
  # (Stripe::Webhook.construct_event), not the JWT bearer token, so we skip
  # the ApplicationController's authenticate_user! and forgery protection.
  skip_forgery_protection
  before_action :verify_stripe_webhook

  def stripe
    Rails.logger.info "[Stripe Webhook] === INCOMING WEBHOOK ==="
    Rails.logger.info "[Stripe Webhook] Req UUID: #{request.uuid}"
    Rails.logger.info "[Stripe Webhook] Content-Type: #{request.content_type}"
    sig = request.headers["HTTP_STRIPE_SIGNATURE"] || request.headers["Stripe-Signature"] || "(missing)"
    Rails.logger.info "[Stripe Webhook] Sig header present: #{sig != "(missing)"}"
    body_size = request.body.read.length
    Rails.logger.info "[Stripe Webhook] Body size: #{body_size} bytes"
    request.body.rewind

    # Parse the verified event.
    event = @stripe_event

    # Idempotent processing: claim the event so it's only processed once.
    claimed = BillingEvent.claim(
      provider: "stripe",
      provider_event_id: event.id,
      event_type: event.type,
      payload: event.to_hash
    )
    Rails.logger.info "[Stripe Webhook] Event parsed - type: #{event.type}, id: #{event.id}"

    # If the event was already processed, acknowledge it silently (Stripe expects 200).
    if claimed.nil?
      Rails.logger.info "[Stripe Webhook] Event #{event.id} already processed - skipping (idempotent)"
      head :ok
      return
    end

    Rails.logger.info "[Stripe Webhook] Dispatch event #{event.id} (#{event.type}) to handler"

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

    Rails.logger.info "[Stripe Webhook] Event #{event.id} processed successfully"
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
    session_id = checkout_session["id"]
    provider_sub_id = checkout_session["subscription"]
    if provider_sub_id.blank?
      Rails.logger.warn "[Stripe Webhook] checkout.session.completed: no subscription id in session #{session_id}"
      return
    end

    customer_id = checkout_session["customer"]
    metadata = checkout_session["metadata"] || {}
    billing_price_id = metadata["billing_price_id"]

    if billing_price_id.blank?
      Rails.logger.warn "[Stripe Webhook] checkout.session.completed: no billing_price_id in metadata for session #{session_id}"
      return
    end

    billing_price = SubscriptionBillingPrice.find_by(id: billing_price_id)
    if billing_price.nil?
      Rails.logger.warn "[Stripe Webhook] checkout.session.completed: SubscriptionBillingPrice #{billing_price_id} not found (session #{session_id})"
      return
    end

    billing_customer = BillingCustomer.find_by(provider: "stripe", provider_customer_id: customer_id)
    if billing_customer.nil?
      email = checkout_session.dig("customer_details", "email")
      user = email && User.find_by(email: email)
      user ||= billing_price.subscription.user_subscriptions.current.first&.user
      if user.nil?
        Rails.logger.warn "[Stripe Webhook] checkout.session.completed: no BillingCustomer for stripe customer #{customer_id}, no user for email #{email.inspect}, and no existing subscriber for subscription #{billing_price.subscription_id} (session #{session_id})"
        return
      end

      billing_customer = BillingCustomer.find_or_create_by!(
        user: user,
        provider: "stripe"
      ) { |bc| bc.provider_customer_id = customer_id }
      if billing_customer.provider_customer_id != customer_id
        billing_customer.update!(provider_customer_id: customer_id)
      end
      Rails.logger.info "[Stripe Webhook] Created BillingCustomer #{billing_customer.id} for user #{user.id} from checkout session #{session_id}"
    end

    Rails.logger.info "[Stripe Webhook] Checkout completed: session=#{session_id} customer=#{customer_id} subscription=#{provider_sub_id} user=#{billing_customer.user_id} price=#{billing_price.id}"

    Billing::Subscription.apply(
      user: billing_customer.user,
      subscription: billing_price.subscription,
      billing_provider: "stripe",
      provider_subscription_id: provider_sub_id
    )

    Rails.logger.info "[Stripe Webhook] Subscription applied: user #{billing_customer.user_id} -> #{billing_price.subscription_id} (provider sub #{provider_sub_id})"
  rescue => e
    Rails.logger.error "[Stripe Webhook] handle_checkout_completed FAILED: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    raise
  end

  def handle_subscription_change(subscription_data)
    adapter = Billing::Providers::Stripe.new
    result = adapter.build_subscription_from_event(subscription_data)
    return if result.nil?

    status = result[:status]
    user = result[:user]
    plan = result[:subscription]
    provider_sub_id = result[:provider_subscription_id]

    case status
    when "active"
      if plan.nil?
        Rails.logger.warn "[Stripe Webhook] subscription.updated #{provider_sub_id} could not map to a local plan — skipping."
        return
      end

      apply_or_dedupe(user, plan, result)
      complete_scheduled_downgrades(user, plan, provider_sub_id)
    when "past_due"
      # Mark the user's subscription as past_due if needed.
      current = user.user_subscriptions.current.first
      current&.update!(status: :past_due)
    end
  end

  # Record a subscription period from a Stripe event, avoiding duplicate rows
  # for unchanged plans / the same billing period (payment-method changes,
  # status flips, retries). Real plan changes apply normally with
  # allow_downgrade so Stripe-confirmed downgrades sync locally.
  def apply_or_dedupe(user, plan, result)
    provider_sub_id = result[:provider_subscription_id]
    period_end = result[:current_period_end]
    previous_plan = user.subscription

    existing = user.user_subscriptions.current
                   .where(billing_provider: "stripe")
                   .where.not(provider_subscription_id: nil)
                   .find_by(provider_subscription_id: provider_sub_id)

    same_plan_same_period = existing && existing.subscription_id == plan.id &&
      (period_end.nil? || existing.current_period_end == period_end)

    if same_plan_same_period
      # Renewal or mid-period event without a plan change — backfill period
      # info if needed but do NOT split the period into a new row.
      if existing.current_period_start.blank? || existing.current_period_end.blank?
        existing.update_columns(
          current_period_start: result[:current_period_start],
          current_period_end: period_end
        )
      end
      log_billing(
        user, previous_plan, plan, provider_sub_id,
        action: "subscription.renewal",
        description: "Subscription renewal (no plan change): #{plan.name} for #{user.user_name || user.email}"
      )
      return
    end

    Billing::Subscription.apply(
      user: user,
      subscription: plan,
      billing_provider: "stripe",
      provider_subscription_id: provider_sub_id,
      current_period_start: result[:current_period_start],
      current_period_end: period_end,
      allow_downgrade: true
    )

    direction =
      if plan.higher_rank_than?(previous_plan) then "upgrade"
      elsif plan.lower_rank_than?(previous_plan) then "downgrade"
      else "change"
      end

    log_billing(
      user, previous_plan, plan, provider_sub_id,
      action: "subscription.change_applied",
      description: "Subscription changed (#{direction}): #{previous_plan&.name} -> #{plan.name} for #{user.user_name || user.email}"
    )
  end

  # When a scheduled downgrade reaches its effective date (the renewal event
  # carries the lower plan), mark it succeeded for the audit/UI trail.
  def complete_scheduled_downgrades(user, plan, provider_sub_id)
    user.subscription_changes.due
        .where(change_type: "downgrade", to_subscription_id: plan.id)
        .find_each do |change|
      change.update!(status: :succeeded)
      log_billing(
        user, change.from_subscription, change.to_subscription, provider_sub_id,
        action: "subscription.downgrade_completed",
        description: "Scheduled downgrade took effect: #{change.from_subscription&.name} -> #{change.to_subscription&.name} for #{user.user_name || user.email}"
      )
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
    user.apply_subscription!(free_plan, allow_downgrade: true)

    log_billing(
      user, current.subscription, free_plan, current.provider_subscription_id,
      action: "subscription.cancelled",
      description: "Subscription cancelled, fell back to #{free_plan.name} for #{user.user_name || user.email}"
    )
  end

  def handle_invoice_paid(invoice)
    # Completes a pending upgrade once Stripe confirms the charge, and retains
    # the audit/amount. The subscription.updated event handles the plan row.
    subscription_id = invoice["subscription"]
    complete_pending_change(
      subscription_id,
      invoice["id"],
      invoice["amount_paid"] || invoice["amount_due"] || invoice["amount_total"],
      invoice["currency"]
    )
    Rails.logger.info "[Stripe Webhook] Invoice paid: #{invoice['id']}"
  end

  def handle_payment_failed(invoice)
    subscription_id = invoice["subscription"]
    if subscription_id.nil?
      Rails.logger.warn "[Stripe Webhook] Payment failed invoice with no subscription: #{invoice['id']}"
      return
    end

    user_sub = UserSubscription.find_by(
      billing_provider: "stripe",
      provider_subscription_id: subscription_id
    )
    user_sub&.update!(status: :past_due)

    change = SubscriptionChange.pending.find_by(provider_subscription_id: subscription_id)
    if change
      change.update!(status: :failed, provider_invoice_id: invoice["id"])
      log_billing(
        change.user, change.from_subscription, change.to_subscription, subscription_id,
        action: "subscription.payment_failed",
        description: "Payment failed for change #{change.from_subscription&.name} -> #{change.to_subscription&.name} (subscription #{subscription_id})"
      )
    else
      log_billing(
        user_sub&.user, nil, nil, subscription_id,
        action: "subscription.payment_failed",
        description: "Payment failed for subscription #{subscription_id}"
      )
    end
    Rails.logger.warn "[Stripe Webhook] Payment failed for subscription #{subscription_id}"
  end

  # Mark the matching pending change succeeded once the invoice is paid.
  def complete_pending_change(subscription_id, invoice_id, amount_cents, currency)
    return if subscription_id.blank?

    change = SubscriptionChange.pending.find_by(provider_subscription_id: subscription_id)
    return if change.nil?

    change.update!(
      status: :succeeded,
      amount_cents: amount_cents.present? ? amount_cents.to_i : change.amount_cents,
      currency: currency.presence || change.currency,
      provider_invoice_id: invoice_id
    )
    log_billing(
      change.user, change.from_subscription, change.to_subscription, subscription_id,
      action: "subscription.change_paid",
      description: "Subscription change paid: #{change.from_subscription&.name} -> #{change.to_subscription&.name} (invoice #{invoice_id})"
    )
  end

  # Append a subscription lifecycle entry to the audit Log (never raises).
  def log_billing(user, from_plan, to_plan, provider_sub_id, action:, description:)
    LogService.log(
      description: description,
      action: action,
      user: user,
      method: request&.request_method || "POST",
      path: request&.path || "webhook/stripe",
      request_id: @stripe_event&.id,
      objects: [user, from_plan, to_plan, provider_sub_id].compact
    )
  end
end