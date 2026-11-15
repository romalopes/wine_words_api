module Trade
  module Invoices
    # Generates an invoice from an ACCEPTED quote (IDENTITY_206 Phase 10) and
    # moves the package to `invoiced`.
    #
    #   * invoice_number allocated from a per-year sequence; a unique-index
    #     race is retried once with a regenerated number;
    #   * the quote is the single source of the amounts — the invoice never
    #     reprices;
    #   * `invoice_created` lands on the package timeline via WinePackageEvent.
    class GenerateFromQuote
      def self.call(quote, by:)
        new(quote, by: by).call
      end

      def initialize(quote, by:)
        @quote = quote
        @by = by
      end

      def call
        raise Error, "only an accepted quote can be invoiced" unless quote.accepted?
        raise Error, "this quote already has an invoice" if existing_invoice

        ActiveRecord::Base.transaction do
          package.transition_to!("invoiced", actor: by)
          invoice = package.wine_package_invoices.create!(
            wine_package_quote: quote,
            invoice_number: allocate_number,
            currency: quote.currency,
            items: quote.items,
            subtotal: quote.subtotal,
            tax: quote.tax,
            total: quote.total,
            status: "sent",
            issued_at: Time.current,
            due_at: 30.days.from_now
          )
          package.wine_package_events.create!(
            event_type: "invoice_created",
            actor: by,
            visibility: "shared",
            occurred_at: Time.current,
            metadata: { wine_package_invoice_id: invoice.id, invoice_number: invoice.invoice_number, total: invoice.total.to_s }
          )
          invoice
        end
      rescue ActiveRecord::RecordNotUnique
        retry_once
      end

      private

      attr_reader :quote, :by

      def package = quote.wine_package

      def existing_invoice
        @existing_invoice ||= package.wine_package_invoices.find_by(wine_package_quote_id: quote.id)
      end

      def allocate_number
        WinePackageInvoice.next_number
      end

      def retry_once
        invoice = nil
        ActiveRecord::Base.transaction do
          invoice = package.wine_package_invoices.create!(
            wine_package_quote: quote,
            invoice_number: WinePackageInvoice.next_number,
            currency: quote.currency,
            items: quote.items,
            subtotal: quote.subtotal,
            tax: quote.tax,
            total: quote.total,
            status: "sent",
            issued_at: Time.current,
            due_at: 30.days.from_now
          )
        end
        invoice
      end
    end
  end
end