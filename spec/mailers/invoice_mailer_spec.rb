require "rails_helper"
require "devise"

# InvoiceMailer (IDENTITY_214 Phase 12): builds the invoice email with the PDF
# attachment and the configurable "from" address (AppSetting.invoice_from_email).
RSpec.describe InvoiceMailer, type: :mailer do
  let(:admin) do
    user = User.create!(first_name: "MailAdmin", email: "mail-admin@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end

  let(:invoice) do
    producer_user = User.create!(first_name: "MailProd", email: "mail-prod@example.com", password: "password123")
    producer = Producer.create!(name: "Mail Spec Producer", slug: "mail-spec-producer")
    pkg = WinePackage.create!(
      producer: producer, status: "editorial_pending", source: "trade_submission",
      submitter: producer_user,
      contact_snapshot: {"company_name" => "Mail Owner Co", "contact_name" => "Mail Owner", "email" => "owner@example.com"},
      wine_package_items_attributes: [{proposed_wine_name: "Spec Wine", proposed_vintage_year: 2023, quantity: 5}]
    )
    pkg.confirm_billable_quantity!(5, by: admin)
    pkg.wine_package_invoices.create!(
      wine_package_quote: nil,
      invoice_number: WinePackageInvoice.next_number,
      currency: "AUD", items: [], subtotal: 50, tax: 5, total: 55,
      status: :sent, issued_at: Time.current, due_at: 30.days.from_now,
      payment_source: :manual, billable_bottle_count: 5, unit_fee: 10.0,
      recorded_by: admin, recorded_at: Time.current
    )
  end

  let(:owner) do
    {
      company_name: "Mail Owner Co", contact_name: "Mail Owner",
      email: "owner@example.com", address: nil, country: "Australia"
    }
  end

  subject(:mail) do
    described_class.invoice_email(invoice, invoice.wine_package, owner, "%PDF-1.4 fake")
  end

  it "addresses the package owner" do
    expect(mail.to).to eq(["owner@example.com"])
  end

  it "sends from the default invoice_from_email with the billing display name" do
    expect(mail.from).to eq([AppSetting::DEFAULTS.fetch("invoice_from_email")])
    expect(mail["From"].to_s).to include("Wine Words Billing")
  end

  it "uses AppSetting.invoice_from_email when configured" do
    AppSetting.set!(:invoice_from_email, "accounts@winewords.com")
    expect(mail.from).to eq(["accounts@winewords.com"])
    expect(mail["From"].to_s).to include("Wine Words Billing")
  end

  it "attaches the invoice PDF under the invoice number" do
    expect(mail.attachments.size).to eq(1)
    attachment = mail.attachments["invoice-#{invoice.invoice_number}.pdf"]
    expect(attachment).to be_present
    expect(attachment.mime_type).to eq("application/pdf")
    expect(attachment.read).to eq("%PDF-1.4 fake")
  end

  it "has a subject naming the invoice number and bottle count" do
    expect(mail.subject).to include(invoice.invoice_number)
    expect(mail.subject).to include("5 bottle(s)")
  end
end
