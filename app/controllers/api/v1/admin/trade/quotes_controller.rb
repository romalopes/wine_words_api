# Trade quotes (IDENTITY_206 Phase 10) — Editor/Admin side.
#
#   POST /api/v1/admin/trade/packages/:package_id/quotes          create draft
#   POST /api/v1/admin/trade/packages/:package_id/quotes/:id/send send it
#   POST /api/v1/admin/trade/packages/:package_id/quotes/:id/accept
#         -> generates the invoice (Trade::Invoices::GenerateFromQuote) and
#            moves the package to `invoiced`
#
# Acceptance by the ADMIN is deliberate for v1: the submitter's Commercial tab
# shows the quote; payment then happens through Stripe Checkout (Phase 11).
class Api::V1::Admin::Trade::QuotesController < ApplicationController
  before_action :ensure_trade_manager!
  before_action :set_package, only: %i[create]
  before_action :set_quote, only: %i[send_quote accept]
  before_action :set_package_for_quote, only: %i[send_quote accept]

  rescue_from Trade::Error, with: :render_trade_error

  # POST /api/v1/admin/trade/packages/:package_id/quotes
  def create
    quote = @package.wine_package_quotes.create!(
      created_by: current_user,
      service_type: params[:service_type] || "review",
      items: quote_items_params,
      currency: params[:currency] || "EUR",
      subtotal: params[:subtotal],
      tax: params[:tax] || 0,
      total: params[:total],
      status: "draft",
      valid_until: params[:valid_until]
    )
    @package.wine_package_events.create!(
      event_type: "quote_created",
      actor: current_user,
      visibility: "shared",
      occurred_at: Time.current,
      metadata: { wine_package_quote_id: quote.id, total: quote.total.to_s }
    )
    render json: TradeQuoteSerializer.new(quote).as_json, status: :created
  end

  # POST .../quotes/:quote_id/send
  def send_quote
    raise Trade::Error, "only a draft quote can be sent" unless @quote.draft?

    @quote.update!(status: "sent", valid_until: @quote.valid_until || 30.days.from_now.to_date)
    # Sending the quote is the business event that moves the package along the
    # commercial chain (approved → quoted, §Phase 10). Idempotent: once quoted
    # (or beyond) the transition is skipped.
    @quote.wine_package.transition_to!("quoted", actor: current_user) if @quote.wine_package.status == "approved"
    render json: TradeQuoteSerializer.new(@quote.reload).as_json
  end

  # POST .../quotes/:quote_id/accept
  def accept
    raise Trade::Error, "only a sent quote can be accepted" unless @quote.status == "sent"

    ActiveRecord::Base.transaction do
      @quote.update!(status: "accepted")
      invoice = Trade::Invoices::GenerateFromQuote.call(@quote, by: current_user)
      render json: {
        quote: TradeQuoteSerializer.new(@quote.reload).as_json,
        invoice: TradeInvoiceSerializer.new(invoice).as_json
      }, status: :created
    end
  end

  private

  def ensure_trade_manager!
    return render json: { error: "forbidden" }, status: :forbidden unless current_user&.catalogue_manager?
  end

  def set_package
    @package = WinePackage.trade_submissions.find_by(id: params[:package_id])
    return render json: { error: "not found" }, status: :not_found if @package.nil?
  end

  def set_quote
    @quote = WinePackageQuote.find(params[:id])
  end

  def set_package_for_quote
    @package = @quote.wine_package
  end

  # items: [{ wine_package_item_id, description, quantity, unit_price }]
  def quote_items_params
    Array(params[:items]).map do |i|
      {
        "wine_package_item_id" => i[:wine_package_item_id],
        "description" => i[:description],
        "quantity" => i[:quantity],
        "unit_price" => i[:unit_price]
      }
    end
  end

  def render_trade_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end
end