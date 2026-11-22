require "rails_helper"
require "devise"

# Manual review-fee invoicing API (IDENTITY_214).
RSpec.describe "Api::V1::WinePackageInvoices", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    user = User.create!(first_name: "InvAdmin", email: "inv-admin@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end
  let(:editor) do
    user = User.create!(first_name: "InvEditor", email: "inv-editor@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Editor")
    user
  end
  let(:reviewer) do
    user = User.create!(first_name: "InvReviewer", email: "inv-reviewer@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Reviewer")
    user
  end
  let(:producer_user) do
    User.create!(first_name: "InvProducer", email: "inv-producer@example.com", password: "password123")
  end

  let(:package) do
    producer = Producer.create!(name: "Inv Test Producer", slug: "inv-test-producer")
    ProducerMembership.create!(user: producer_user, producer: producer, membership_type: "owner")
    pkg = WinePackage.create!(
      producer: producer,
      reviewer: reviewer,
      status: "editorial_pending",
      source: "trade_submission",
      submitter: producer_user,
      contact_snapshot: {
        "company_name" => "Inv Test Producer",
        "contact_name" => "Inv Owner",
        "email" => "inv-owner@example.com"
      },
      wine_package_items_attributes: [
        { proposed_wine_name: "Test Wine 1", proposed_vintage_year: 2023, quantity: 3 },
        { proposed_wine_name: "Test Wine 2", proposed_vintage_year: 2022, quantity: 2 }
      ]
    )
    pkg.confirm_billable_quantity!(5, by: admin)
    pkg
  end

  def create_invoice(invoice, attrs = {})
    invoice.wine_package_invoices.create!(
      {
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD",
        items: [],
        subtotal: 250,
        tax: 0,
        total: 250,
        status: :sent,
        issued_at: Time.current,
        due_at: 30.days.from_now,
        payment_source: :manual,
        billable_bottle_count: 5,
        unit_fee: 50,
        recorded_by: admin,
        recorded_at: Time.current
      }.merge(attrs)
    )
  end

  after do
    AppSetting.where(key: %w[wine_review_fee_amount wine_review_fee_currency]).destroy_all
  end

  describe "POST /api/v1/wine_packages/:wine_package_id/invoices" do
    it "returns 401 when unauthenticated" do
      post "/api/v1/wine_packages/#{package.id}/invoices", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 422 when the billable quantity has not been confirmed" do
      package.update_columns(billable_bottle_count: nil, billable_confirmed_at: nil)
      sign_in admin

      post "/api/v1/wine_packages/#{package.id}/invoices", as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Billable bottle count must be confirmed first")
    end

    it "creates a manual invoice for the delta at the current fee" do
      sign_in admin

      expect {
        post "/api/v1/wine_packages/#{package.id}/invoices", as: :json
      }.to change { package.wine_package_invoices.manual.count }.by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json).to include(
        "status" => "sent",
        "payment_source" => "manual",
        "billable_bottle_count" => 5,
        "unit_fee" => "50.00",
        "total" => "250.00",
        "currency" => "AUD"
      )
      expect(json["invoice_number"]).to match(/\AWW-\d{4}-\d{4}\z/)
    end

    it "records an invoice_recorded event" do
      sign_in admin

      expect {
        post "/api/v1/wine_packages/#{package.id}/invoices", as: :json
      }.to change { package.wine_package_events.where(event_type: "invoice_recorded").count }.by(1)
    end

    it "invoices only the delta when additional bottles are accepted later" do
      sign_in admin
      post "/api/v1/wine_packages/#{package.id}/invoices", as: :json
      expect(response).to have_http_status(:created)

      package.confirm_billable_quantity!(8, by: admin)
      post "/api/v1/wine_packages/#{package.id}/invoices", as: :json

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["billable_bottle_count"]).to eq(3)
      expect(json["total"]).to eq("150.00")

      first_invoice = package.wine_package_invoices.manual.first
      expect(first_invoice.billable_bottle_count).to eq(5)
      expect(first_invoice.total).to eq(250.0)
    end

    it "excludes cancelled invoices from the difference" do
      sign_in admin
      post "/api/v1/wine_packages/#{package.id}/invoices", as: :json
      first_id = JSON.parse(response.body)["id"]

      post "/api/v1/wine_packages/#{package.id}/invoices/#{first_id}/cancel",
           params: { cancellation_reason: "Wrong amount" }, as: :json
      expect(response).to have_http_status(:ok)

      # The cancelled invoice releases its bottles, so a fresh invoice covers
      # the full billable count again.
      post "/api/v1/wine_packages/#{package.id}/invoices", as: :json
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["billable_bottle_count"]).to eq(5)
    end

    it "supports coverage=full to consolidate the whole billable count" do
      sign_in admin
      package.confirm_billable_quantity!(8, by: admin)
      post "/api/v1/wine_packages/#{package.id}/invoices", as: :json
      expect(JSON.parse(response.body)["billable_bottle_count"]).to eq(8)

      # Difference mode is now blocked — every bottle is covered by the sent invoice…
      post "/api/v1/wine_packages/#{package.id}/invoices", as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      # …but full mode re-issues one consolidated invoice for the whole count.
      post "/api/v1/wine_packages/#{package.id}/invoices", params: { coverage: "full" }, as: :json
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["billable_bottle_count"]).to eq(8)
      expect(json["total"]).to eq("400.00")
    end

    it "is forbidden for the producer member" do
      sign_in producer_user
      post "/api/v1/wine_packages/#{package.id}/invoices", as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST .../invoices/:id/mark_paid" do
    let(:invoice) { create_invoice(package) }

    it "returns 401 when unauthenticated" do
      post "/api/v1/wine_packages/#{package.id}/invoices/#{invoice.id}/mark_paid", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "marks a sent invoice paid and records the event" do
      sign_in admin

      expect {
        post "/api/v1/wine_packages/#{package.id}/invoices/#{invoice.id}/mark_paid", as: :json
      }.to change { package.wine_package_events.where(event_type: "invoice_marked_paid").count }.by(1)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("paid")
      expect(json["paid_at"]).to be_present
    end

    it "refuses to mark a draft invoice paid" do
      invoice.update_columns(status: "draft")
      sign_in admin

      post "/api/v1/wine_packages/#{package.id}/invoices/#{invoice.id}/mark_paid", as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Only sent invoices can be marked paid")
    end
  end

  describe "POST .../invoices/:id/cancel" do
    let(:invoice) { create_invoice(package) }

    it "returns 401 when unauthenticated" do
      post "/api/v1/wine_packages/#{package.id}/invoices/#{invoice.id}/cancel", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "cancels with a reason and records the event" do
      sign_in admin

      expect {
        post "/api/v1/wine_packages/#{package.id}/invoices/#{invoice.id}/cancel",
             params: { cancellation_reason: "Client requested waiver" }, as: :json
      }.to change { package.wine_package_events.where(event_type: "invoice_cancelled").count }.by(1)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("cancelled")
      expect(json["cancellation_reason"]).to eq("Client requested waiver")
    end

    it "requires a cancellation reason" do
      sign_in admin
      post "/api/v1/wine_packages/#{package.id}/invoices/#{invoice.id}/cancel", as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Cancellation reason is required")
    end

    it "refuses to cancel a paid invoice" do
      invoice.update!(status: :paid, paid_at: Time.current)
      sign_in admin

      post "/api/v1/wine_packages/#{package.id}/invoices/#{invoice.id}/cancel",
           params: { cancellation_reason: "Test" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Paid invoices cannot be cancelled")
    end
  end

  describe "invoice PDF and email (IDENTITY_214 Phase 12)" do
    let(:invoice) { create_invoice(package) }

    it "streams the invoice PDF" do
      sign_in admin
      get "/api/v1/wine_packages/#{package.id}/invoices/#{invoice.id}/pdf"

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to include("application/pdf")
      expect(response.body.first(4)).to eq("%PDF")
    end

    it "embeds the Wine Words logo image in the PDF" do
      sign_in admin
      get "/api/v1/wine_packages/#{package.id}/invoices/#{invoice.id}/pdf"

      expect(response).to have_http_status(:ok)
      # Prawn writes image XObjects with /Subtype /Image in the object dict
      expect(response.body).to include("/Image")
    end

    it "queues the invoice email job" do
      sign_in admin

      expect {
        post "/api/v1/wine_packages/#{package.id}/invoices/#{invoice.id}/send_email", as: :json
      }.to have_enqueued_job(InvoiceMailerJob)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["queued"]).to be(true)
    end

    it "queues the invoice email again on resend" do
      sign_in admin

      expect {
        post "/api/v1/wine_packages/#{package.id}/invoices/#{invoice.id}/send_email", as: :json
        post "/api/v1/wine_packages/#{package.id}/invoices/#{invoice.id}/send_email", as: :json
      }.to have_enqueued_job(InvoiceMailerJob).twice
    end

    it "delivers every time the job runs and counts each send" do
      ActionMailer::Base.deliveries.clear

      expect {
        InvoiceMailerJob.perform_now(invoice.id, triggered_by_id: admin.id)
      }.to change { invoice.reload.email_send_count }.from(0).to(1)

      # The second run must NOT be silently skipped — staff re-sends on purpose.
      expect {
        InvoiceMailerJob.perform_now(invoice.id, triggered_by_id: admin.id)
      }.to change { invoice.reload.email_send_count }.from(1).to(2)

      expect(ActionMailer::Base.deliveries.count).to eq(2)
      expect(invoice.reload.email_sent_at).to be_present
    end
  end
end

