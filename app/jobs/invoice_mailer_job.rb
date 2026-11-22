class InvoiceMailerJob < ApplicationJob
  queue_as :background

  # Sends an invoice PDF to the package owner via email.
  #
  # @param invoice_id [Integer] WinePackageInvoice ID
  # @param triggered_by_id [Integer] User ID of staff who triggered the send
  def perform(invoice_id, triggered_by_id: nil)
    invoice = WinePackageInvoice.find(invoice_id)
    package = invoice.wine_package
    triggered_by = triggered_by_id && User.find_by(id: triggered_by_id)

    return if invoice.email_sent_at.present? && invoice.email_send_count > 0 && invoice.status != "draft"

    # Generate PDF
    pdf_service = WinePackages::InvoicePdfService.call(invoice)
    pdf_binary = pdf_service.render

    # Resolve owner details
    pdf_service_instance = WinePackages::InvoicePdfService.new(invoice)
    owner = pdf_service_instance.send(:resolve_owner)

    # Send email
    InvoiceMailer.invoice_email(invoice, package, owner, pdf_binary).deliver_now

    # Update tracking fields
    invoice.update_columns(
      email_sent_at: Time.current,
      email_send_count: invoice.email_send_count + 1
    )

    # Record audit event
    package.wine_package_events.create!(
      event_type: "invoice_emailed",
      actor: triggered_by,
      visibility: "shared",
      occurred_at: Time.current,
      metadata: {
        wine_package_invoice_id: invoice.id,
        invoice_number: invoice.invoice_number,
        recipient: pdf_service_instance.send(:resolve_owner)[:email]
      }
    )
  rescue StandardError => e
    Rails.logger.error("[InvoiceMailerJob] Failed to send invoice #{invoice_id}: #{e.class} - #{e.message}")
    raise
  end
end