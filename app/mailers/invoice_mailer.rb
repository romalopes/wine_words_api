class InvoiceMailer < ApplicationMailer
  # Sends the invoice PDF to the package owner.
  #
  # @param invoice [WinePackageInvoice] the invoice to send
  # @param package [WinePackage] the associated wine package
  # @param owner [Hash] owner details from InvoicePdfService#resolve_owner
  # @param pdf_binary [String] the generated PDF binary
  def invoice_email(invoice, package, owner, pdf_binary)
    @invoice = invoice
    @package = package
    @owner = owner

    attachments["invoice-#{invoice.invoice_number}.pdf"] = {
      mime_type: "application/pdf",
      content: pdf_binary
    }

    subject = "Wine Words Invoice ##{invoice.invoice_number} — Review of #{invoice.billable_bottle_count} bottle(s)"

    mail(
      to: owner[:email],
      subject: subject,
      from: email_address_with_name(
        AppSetting.mail_transport == "test" ? AppSetting.test_email : AppSetting.invoice_from_email,
        "Wine Words Billing"
      )
    )
  end
end