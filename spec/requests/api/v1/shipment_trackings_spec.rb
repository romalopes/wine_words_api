require "rails_helper"

# Request specs for Api::V1::ShipmentTrackingsController — the carrier-agnostic
# tracking side of a package. Nothing here may depend on a carrier account.
RSpec.describe "Api::V1::ShipmentTrackings", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:producer) { Producer.create!(name: "Penfolds") }
  let(:admin) do
    user = User.create!(user_name: "Track Admin", email: "track-admin@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end
  let(:outsider) { User.create!(user_name: "Track Outsider", email: "track-outsider@example.com", password: "password123") }
  let(:package) do
    WinePackage.create!(producer: producer, reviewer: admin, created_by: admin,
                        source: "unexpected", status: "announced")
  end

  before { sign_in admin }

  def tracking_url
    "/api/v1/wine_packages/#{package.id}/shipment_tracking"
  end

  describe "GET /api/v1/wine_packages/:wine_package_id/shipment_tracking" do
    it "returns 404 when nothing has been recorded yet" do
      get tracking_url
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to include("No tracking recorded")
    end

    it "returns the tracking row with its event history" do
      ShipmentTracking.create!(wine_package: package, carrier: "Aramex",
                               number: "AR1", provider: "manual", status: "In transit")
      ShipmentTrackingEvent.record_from_provider!(package, { external_id: "e1",
                                                             status: "Departed",
                                                             event_at: Time.current,
                                                             location: "Sydney" })

      get tracking_url

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to include(
        "carrier" => "Aramex",
        "number" => "AR1",
        "provider" => "manual",
        "provider_configured" => true,
        "status" => "In transit",
        "delivered" => false
      )
      expect(body["events"].length).to eq(1)
      expect(body["events"].first).to include("status" => "Departed", "location" => "Sydney",
                                              "external_id" => "e1")
    end

    it "is forbidden for an unrelated user" do
      sign_in outsider
      get tracking_url
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/wine_packages/:wine_package_id/shipment_tracking" do
    it "creates the tracking row and syncs the package snapshot" do
      patch tracking_url, as: :json, params: {
        shipment_tracking: { carrier: "Aramex", number: "AR123", status: "In transit" }
      }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to include("carrier" => "Aramex", "number" => "AR123", "status" => "In transit")

      package.reload
      expect(package.tracking_carrier).to eq("Aramex")
      expect(package.tracking_number).to eq("AR123")
      expect(package.tracking_status).to eq("In transit")
      expect(package.status).to eq("announced")
    end

    it "infers the Australia Post provider from the carrier name" do
      patch tracking_url, as: :json, params: {
        shipment_tracking: { carrier: "Australia Post", number: "AP123" }
      }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["provider"]).to eq("australia_post")
    end

    it "updates the existing row instead of creating a second one" do
      patch tracking_url, as: :json, params: {
        shipment_tracking: { carrier: "Aramex", number: "AR123", status: "In transit" }
      }
      expect(response).to have_http_status(:created)

      patch tracking_url, as: :json, params: {
        shipment_tracking: { status: "Out for delivery" }
      }

      expect(response).to have_http_status(:ok)
      expect(ShipmentTracking.where(wine_package: package).count).to eq(1)
      expect(package.reload.tracking_status).to eq("Out for delivery")
    end

    it "is forbidden for an unrelated user" do
      sign_in outsider
      patch tracking_url, as: :json, params: { shipment_tracking: { carrier: "Aramex" } }
      expect(response).to have_http_status(:forbidden)
    end

    it "audits a creation and a subsequent update under distinct action names" do
      patch tracking_url, as: :json, params: {
        shipment_tracking: { carrier: "Aramex", number: "AR1" }
      }
      expect(Log.where(action: "shipment_tracking.created").count).to eq(1)

      patch tracking_url, as: :json, params: { shipment_tracking: { status: "In transit" } }

      expect(Log.where(action: "shipment_tracking.created").count).to eq(1)
      expect(Log.where(action: "shipment_tracking.updated").count).to eq(1)
    end
  end

  describe "POST /api/v1/wine_packages/:wine_package_id/shipment_tracking/refresh" do
    it "refuses to refresh when nothing is recorded" do
      post "#{tracking_url}/refresh"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "refuses to refresh without a consignment number" do
      ShipmentTracking.create!(wine_package: package, carrier: "Aramex", provider: "manual")
      post "#{tracking_url}/refresh"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("consignment number")
    end

    it "refreshes a manual shipment without wiping what the reviewer recorded" do
      tracking = ShipmentTracking.create!(wine_package: package, carrier: "Aramex",
                                          number: "AR1", provider: "manual",
                                          status: "In transit",
                                          estimated_delivery_at: Time.current + 2.days)

      post "#{tracking_url}/refresh"

      expect(response).to have_http_status(:ok)
      tracking.reload
      expect(tracking.status).to eq("In transit")
      expect(tracking.estimated_delivery_at).to be_present
      expect(tracking.status_updated_at).to be_present
      expect(tracking.shipment_tracking_events.count).to eq(0)
      expect(package.reload.arrived_at).to be_nil
    end

    it "builds the Australia Post tracking URL without any credentials" do
      ShipmentTracking.create!(wine_package: package, carrier: "Australia Post",
                               number: "AP999", provider: "australia_post")

      post "#{tracking_url}/refresh"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["url"]).to include("AP999")
      expect(body["provider_configured"]).to be false
    end
  end
end
