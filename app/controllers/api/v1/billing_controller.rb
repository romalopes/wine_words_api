class Api::V1::BillingController < ApplicationController
  audit_actions change_preview: "subscription.change_preview", change_confirm: "subscription.change"

  def log_description
    target = Subscription.find_by(id: params[:subscription_id])
    action_name == "change_confirm" ?
      "Requested subscription change to \"#{target&.name}\"" :
      "Previewed subscription change to \"#{target&.name}\""
  end

  def log_objects
    [current_user, Subscription.find_by(id: params[:subscription_id])].compact
  end

  # POST /api/v1/billing/checkout
  # Create a Stripe Checkout Session for the authenticated user.
  # Body: { subscription_id: 2 }
  # Returns: { url: "https://checkout.stripe.com/...", session_id: "cs_..." }
  def checkout
    subscription = Subscription.find(params[:subscription_id])

    unless subscription.active? && subscription.visible? && !subscription.free?
      render json: { error: "This subscription is not available for purchase." }, status: :unprocessable_entity
      return
    end

    result = Billing::Checkout.create(user: current_user, subscription: subscription)
    render json: result
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Subscription not found" }, status: :not_found
  rescue Billing::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/billing/portal
  # Returns a Stripe Customer Portal session URL.
  # Body: (none)
  # Returns: { url: "https://billing.stripe.com/..." } or 422 when no customer.
  def portal
    result = Billing::Portal.create(user: current_user)
    if result
      render json: result
    else
      render json: { error: "No billing customer found. Have you purchased a subscription?" }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/billing/confirm
  # Reconcile a Stripe Checkout Session after the user returns from Stripe.
  # Body: { session_id: "cs_..." }
  # This is the safety net for when the `checkout.session.completed` webhook
  # has not been delivered yet (e.g. `stripe listen` not running locally).
  # It verifies the session server-side (paid + complete + belongs to the
  # current user's billing customer) and applies the plan via the same
  # Billing::Subscription.apply path the webhook uses.
  # Returns: { applied: true, subscription_id:, status: } or an error status.
  def confirm
    unless Billing.stripe_enabled?
      render json: { error: "Billing is not configured." }, status: :unprocessable_entity
      return
    end

    session_id = params[:session_id].to_s.strip
    if session_id.blank?
      render json: { error: "session_id is required." }, status: :bad_request
      return
    end

    result = Billing::ConfirmCheckout.call(user: current_user, session_id: session_id)
    if result[:applied]
      render json: result, status: :ok
    else
      render json: result, status: :accepted
    end
  rescue Billing::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/billing/change/preview
  # Preview a plan change (upgrade or downgrade) without charging.
  # Body: { subscription_id: 2 }
  # Returns the summary the UI shows before confirmation.
  def change_preview
    subscription = Subscription.find(params[:subscription_id])
    result = Billing::ChangeSubscription.preview(user: current_user, target_subscription: subscription)
    render json: result
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Subscription not found" }, status: :not_found
  rescue Billing::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/billing/change/confirm
  # Execute a plan change.
  # Body: { subscription_id: 2, idempotency_key: "<uuid>" }
  # - upgrade: Stripe invoices the prorated difference; status "pending" (202)
  #   until the webhook confirms (the UI polls /me).
  # - downgrade: scheduled at next renewal; status "scheduled" (200).
  def change_confirm
    subscription = Subscription.find(params[:subscription_id])
    idempotency_key = params[:idempotency_key].to_s.strip
    if idempotency_key.blank?
      render json: { error: "idempotency_key is required." }, status: :bad_request
      return
    end

    result = Billing::ChangeSubscription.confirm(
      user: current_user,
      target_subscription: subscription,
      idempotency_key: idempotency_key
    )

    render json: result, status: (result[:status] == "pending" ? :accepted : :ok)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Subscription not found" }, status: :not_found
  rescue Billing::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end