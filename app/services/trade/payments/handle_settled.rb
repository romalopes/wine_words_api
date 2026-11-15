module Trade
  module Payments
    # Webhook-side settlement for a Trade invoice (IDENTITY_206 Phase 11).
    #
    # Invoked from Api::V1::WebhooksController#stripe for checkout.session.completed /
    # payment_intent.succeeded events whose metadata carries trade_invoice_id.
    # Event-level idempotency is provided by BillingEvent.claim in the webhook
    # controller — this handler may assume it runs once per event.
    class HandleSettled
      def self.call(invoice:, payment_intent_id: nil, session_id: nil, metadata: {})
        new(invoice: invoice, payment_intent_id: payment_intent_id, session_id: session_id, metadata: metadata).call
      end

      def initialize(invoice:, payment_intent_id: nil, session_id: nil, metadata: {})
        @invoice = invoice
        @payment_intent_id = payment_intent_id
        @session_id = session_id
        @metadata = metadata
      end

      def call
        return invoice if invoice.paid?

        ActiveRecord::Base.transaction do
          invoice.update!(
            status: "paid",
            paid_at: Time.current,
            stripe_payment_intent_id: payment_intent_id,
            stripe_payment_metadata: metadata
          )
          package.transition_to!("paid", actor: nil)
          package.wine_package_events.create!(
            event_type: "payment_received",
            visibility: "shared",
            occurred_at: Time.current,
            metadata: {
              wine_package_invoice_id: invoice.id,
              invoice_number: invoice.invoice_number,
              total: invoice.total.to_s
            }
          )
        end
        invoice
      end

      private

      attr_reader :invoice, :payment_intent_id, :session_id, :metadata

      def package = invoice.wine_package
    end
  end
end