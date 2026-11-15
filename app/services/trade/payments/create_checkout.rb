module Trade
  module Payments
    # Opens a Stripe Checkout Session for a Trade invoice (IDENTITY_206
    # Phase 11) and stores the session id on the invoice for reconciliation.
    #
    # Security model (§11.6 of the plan):
    #   * PCI SAQ-A — card data never touches Wine Words servers;
    #   * the invoice is ONLY marked paid by the webhook handler
    #     (HandleSettled), never by the redirect back from Stripe;
    #   * metadata.trade_invoice_id is the reconciliation key the webhook uses.
    class CreateCheckout
      def self.call(invoice, success_url:, cancel_url:)
        new(invoice, success_url: success_url, cancel_url: cancel_url).call
      end

      def initialize(invoice, success_url:, cancel_url:)
        @invoice = invoice
        @success_url = success_url
        @cancel_url = cancel_url
      end

      def call
        raise Error, "only a sent invoice can be paid" unless invoice.status == "sent"

        session = Stripe::Checkout::Session.create(
          mode: "payment",
          customer_email: package.contact_email,
          line_items: [line_item],
          metadata: metadata,
          success_url: success_url,
          cancel_url: cancel_url
        )
        invoice.update!(stripe_checkout_session_id: session.id)
        session
      end

      private

      attr_reader :invoice, :success_url, :cancel_url

      def package = invoice.wine_package

      def line_item
        {
          quantity: 1,
          price_data: {
            currency: invoice.currency.downcase,
            unit_amount: (invoice.total * 100).round,
            product_data: {
              name: "Wine Words — invoice #{invoice.invoice_number}",
              description: "Trade package review/listing services"
            }
          }
        }
      end

      def metadata
        {
          trade_invoice_id: invoice.id,
          trade_package_id: package.id,
          invoice_number: invoice.invoice_number
        }
      end
    end
  end
end