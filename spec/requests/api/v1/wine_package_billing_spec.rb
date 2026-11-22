require "rails_helper"
require "devise"

RSpec.describe "Api::V1::WinePackageBilling", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    user = User.create!(first_name: "BillingAdmin", email: "billing-admin@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end

  let(:editor) do
    user = User.create!(first_name: "BillingEditor", email: "billing-editor@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Editor")
    user
  end

  let(:reviewer) do
    user = User.create!(first_name: "BillingReviewer", email: "billing-reviewer@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Reviewer")
    user
  end

  let(:producer_user) do
    # No role needed: the producer-side access comes from ProducerMembership.
    User.create!(first_name: "BillingProducer", email: "billing-producer@example.com", password: "password123")
  end

  let(:package) do
    producer = Producer.create!(name: "Billing Test Producer", slug: "billing-test-producer")
    membership = ProducerMembership.create!(user: producer_user, producer: producer, membership_type: "owner")
    WinePackage.create!(
      producer: producer,
      reviewer: reviewer,
      status: "editorial_pending",
      source: "trade_submission",
      submitter: producer_user,
      contact_snapshot: {
        "company_name" => "Billing Test Producer",
        "contact_name" => "Billing Owner",
        "email" => "billing-owner@example.com"
      },
      wine_package_items_attributes: [
        { proposed_wine_name: "Test Wine 1", proposed_vintage_year: 2023, quantity: 3 },
        { proposed_wine_name: "Test Wine 2", proposed_vintage_year: 2022, quantity: 2 }
      ]
    )
  end

  after do
    AppSetting.where(key: %w[wine_review_fee_amount wine_review_fee_currency]).destroy_all
  end

  describe "GET /api/v1/wine_packages/:wine_package_id/billing" do
    context "when unauthenticated" do
      it "returns 401" do
        get "/api/v1/wine_packages/#{package.id}/billing"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when authenticated as admin" do
      before { sign_in admin }

      it "returns billing summary" do
        get "/api/v1/wine_packages/#{package.id}/billing"
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to have_key("bottles_submitted")
        expect(json).to have_key("billable_to_date")
        expect(json).to have_key("total_invoiced")
        expect(json).to have_key("total_paid")
        expect(json).to have_key("outstanding")
        expect(json).to have_key("payment_state")
        expect(json).to have_key("overdue")
        expect(json).to have_key("invoices")
      end
    end

    context "when authenticated as editor" do
      before { sign_in editor }

      it "returns billing summary" do
        get "/api/v1/wine_packages/#{package.id}/billing"
        expect(response).to have_http_status(:ok)
      end
    end

    context "when authenticated as reviewer (assigned)" do
      before { sign_in reviewer }

      it "returns billing summary" do
        get "/api/v1/wine_packages/#{package.id}/billing"
        expect(response).to have_http_status(:ok)
      end
    end

    context "when authenticated as producer member" do
      before { sign_in producer_user }

      it "returns billing summary" do
        get "/api/v1/wine_packages/#{package.id}/billing"
        expect(response).to have_http_status(:ok)
      end
    end

    context "when authenticated as unrelated user" do
      let(:other_user) { User.create!(first_name: "Other", email: "other@example.com", password: "password123") }
      before { sign_in other_user }

      it "returns 403" do
        get "/api/v1/wine_packages/#{package.id}/billing"
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /api/v1/wine_packages/:wine_package_id/billing (confirm billable)" do
    context "when unauthenticated" do
      it "returns 401" do
        patch "/api/v1/wine_packages/#{package.id}/billing", params: { billable_bottle_count: 5 }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when authenticated as admin" do
      before { sign_in admin }

      it "confirms billable quantity and records event" do
        expect {
          patch "/api/v1/wine_packages/#{package.id}/billing", params: { billable_bottle_count: 5 }, as: :json
        }.to change { package.wine_package_events.count }.by(1)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["billable_to_date"]).to eq(5)

        event = package.wine_package_events.last
        expect(event.event_type).to eq("billable_quantity_confirmed")
        expect(event.metadata["billable_bottle_count"]).to eq(5)
      end

      it "rejects non-integer count" do
        patch "/api/v1/wine_packages/#{package.id}/billing", params: { billable_bottle_count: "abc" }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects zero or negative count" do
        patch "/api/v1/wine_packages/#{package.id}/billing", params: { billable_bottle_count: 0 }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)

        patch "/api/v1/wine_packages/#{package.id}/billing", params: { billable_bottle_count: -1 }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects missing count" do
        patch "/api/v1/wine_packages/#{package.id}/billing", params: {}, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when authenticated as editor" do
      before { sign_in editor }

      it "confirms billable quantity" do
        patch "/api/v1/wine_packages/#{package.id}/billing", params: { billable_bottle_count: 5 }, as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context "when authenticated as the assigned reviewer" do
      before { sign_in reviewer }

      it "confirms billable quantity (editorial_manage? covers the assigned reviewer)" do
        patch "/api/v1/wine_packages/#{package.id}/billing", params: { billable_bottle_count: 5 }, as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context "when authenticated as producer member" do
      before { sign_in producer_user }

      it "returns 403" do
        patch "/api/v1/wine_packages/#{package.id}/billing", params: { billable_bottle_count: 5 }, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end