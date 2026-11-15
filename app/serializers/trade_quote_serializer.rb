# Trade quote payloads (IDENTITY_206 Phase 10).
class TradeQuoteSerializer
  def initialize(quote, base_url = nil)
    @quote = quote
    @base_url = base_url
  end

  def as_json(*)
    {
      id: @quote.id,
      service_type: @quote.service_type,
      status: @quote.status,
      currency: @quote.currency,
      items: @quote.items,
      subtotal: @quote.subtotal,
      tax: @quote.tax,
      total: @quote.total,
      valid_until: @quote.valid_until,
      created_at: @quote.created_at&.iso8601
    }
  end
end
