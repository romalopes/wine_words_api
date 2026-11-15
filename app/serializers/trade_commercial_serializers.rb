# Trade quote/invoice payloads (IDENTITY_206 Phase 10/11).
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

class TradeInvoiceSerializer
  def initialize(invoice, base_url = nil)
    @invoice = invoice
    @base_url = base_url
  end

  def as_json(*)
    {
      id: @invoice.id,
      invoice_number: @invoice.invoice_number,
      status: @invoice.status,
      currency: @invoice.currency,
      items: @invoice.items,
      subtotal: @invoice.subtotal,
      tax: @invoice.tax,
      total: @invoice.total,
      issued_at: @invoice.issued_at&.iso8601,
      due_at: @invoice.due_at&.iso8601,
      paid_at: @invoice.paid_at&.iso8601
    }
  end
end