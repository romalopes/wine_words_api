# Stripe Checkout for Trade invoices (IDENTITY_206 Phase 11) — submitter side.
#
#   POST /api/v1/trade/invoices/:invoice_id/checkout
#
# The owner (or a guest-token holder) opens a Checkout Session; the invoice is
# marked paid ONLY by the Stripe webhook (Api::V1::WebhooksController -> 
# Trade::Payments::HandleSettled), never by the redirect — the client cannot
# forge a payment state.
class Api::V1::Trade::PaymentsController < ApplicationController
  before_action :set_invoice_and_package

  rescue_from Trade::Error, with: :render_trade_error
  rescue_from Stripe::StripeError, with: :render_stripe_error

  def create
    session = Trade::Payments::CreateCheckout.call(
      @invoice,
      success_url: params[:success_url] || "#{request.base_url}/trade/payment/success",
      cancel_url: params[:cancel_url] || "#{request.base_url}/trade/payment/cancel"
    )
    render json: { checkout_url: session.url, session_id: session.id }
  end

  private

  def set_invoice_and_package
    @invoice = WinePackageInvoice.find_by(id: params[:invoice_id])
    return render json: { error: "not found" }, status: :not_found if @invoice.nil?

    @package = @invoice.wine_package
    owner = current_user && @package.submitter_id == current_user.id
    guest = params[:guest_token].present? && @package.guest_token_valid?(params[:guest_token])
    return render json: { error: "not found" }, status: :not_found unless owner || guest
  end

  def render_trade_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def render_stripe_error(error)
    Rails.logger.error("[Trade Payments] Stripe error: #{error.message}")
    render json: { error: "payment provider error" }, status: :bad_gateway
  end
end