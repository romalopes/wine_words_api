class Api::V1::BillingController < ApplicationController
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
end