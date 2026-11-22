require "rails_helper"
require "devise"

# Staff-wide invoice overview (IDENTITY_214): GET /api/v1/invoices.
# Admins and Editors only — mirrors the per-package billing permissions.
RSpec.describe "Api::V1::Invoices", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    user = User.create!(first_name: "InvListAdmin", email: "invlist-admin@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end
  let(:editor) do
    user = User.create!(first_name: "InvListEditor", email: "invlist-editor@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Editor")
    user
  end
  let(:reviewer) do
    user = User.create!(first_name: "InvListReviewer", email: "invlist-reviewer@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Reviewer")
    user
  end
  let(:producer_user) do
    User.create!(first_name: "InvListProd", email: "invlist-prod@example.com", password: "password123")
  end

  let!(:package) do
    producer = Producer.create!(name: "Inv List Producer", slug: "inv-list-producer")
    ProducerMembership.create!(user: producer_user, producer: producer, membership_type: "owner")
    pkg = WinePackage.create!(
      producer: producer,
      reviewer: reviewer,
      status: "editorial_pending",
      source: "trade_submission",
      submitter: producer_user,
      contact_snapshot: {
        "company_name" => "Inv List Co",
        "contact_name" => "List Owner",
        "email" => "list-owner@example.com"
      },
      wine_package_items_attributes: [
        { proposed_wine_name: "List Wine 1", proposed_vintage_year: 2023, quantity: 3 }
      ]
    )
    pkg.confirm_billable_quantity!(3, by: admin)
    pkg
  end

  let!(:invoice) do
    package.wine_package_invoices.create!(
      wine_package_quote: nil,
      invoice_number: WinePackageInvoice.next_number,
      currency: "AUD", items: [], subtotal: 30, tax: 3, total: 33,
      status: :sent, issued_at: Time.current, due_at: 30.days.from_now,
      payment_source: :manual, billable_bottle_count: 3, unit_fee: 10.0,
      recorded_by: admin, recorded_at: Time.current
    )
  end

  it "returns 401 when unauthenticated" do
    get "/api/v1/invoices"
    expect(response).to have_http_status(:unauthorized)
  end

  it "is forbidden for producer members and reviewers" do
    sign_in producer_user
    get "/api/v1/invoices"
    expect(response).to have_http_status(:forbidden)

    sign_in reviewer
    get "/api/v1/invoices"
    expect(response).to have_http_status(:forbidden)
  end

  it "lists invoices with client and package context for admins" do
    sign_in admin
    get "/api/v1/invoices"

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    row = json.find { |entry| entry["id"] == invoice.id }
    expect(row).to include(
      "invoice_number" => invoice.invoice_number,
      "status" => "sent",
      "payment_source" => "manual",
      "billable_bottle_count" => 3,
      "total" => "33.00"
    )
    expect(row["client"]).to include(
      "company_name" => "Inv List Co",
      "contact_name" => "List Owner",
      "email" => "list-owner@example.com"
    )
    expect(row["wine_package"]).to include(
      "id" => package.id,
      "source" => "trade_submission",
      "producer_name" => "Inv List Producer",
      "item_count" => 1
    )
  end

  it "is available to editors and excludes draft invoices" do
    draft = package.wine_package_invoices.create!(
      wine_package_quote: nil,
      invoice_number: WinePackageInvoice.next_number,
      currency: "AUD", items: [], subtotal: 10, tax: 0, total: 10,
      status: :draft, payment_source: :manual,
      billable_bottle_count: 1, unit_fee: 10.0,
      recorded_by: admin, recorded_at: Time.current
    )

    sign_in editor
    get "/api/v1/invoices"

    expect(response).to have_http_status(:ok)
    ids = JSON.parse(response.body).map { |row| row["id"] }
    expect(ids).to include(invoice.id)
    expect(ids).not_to include(draft.id)
  end
end
