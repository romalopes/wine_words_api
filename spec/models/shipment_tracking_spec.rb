require "rails_helper"

# Unit specs for ShipmentTracking — the carrier-independent tracking row.
#
# The contract that matters: provider resolution is derived from the carrier,
# a refresh is never destructive, and a carrier "Delivered" never marks the
# package as arrived.
RSpec.describe ShipmentTracking, type: :model do
  let(:producer) { Producer.create!(name: "Phase F Tracking Producer") }
  let(:reviewer) { create_user("Phase F Tracking Reviewer", "phase-f-tracking@example.com") }
  let(:package) { create_package }

  def create_user(name, email)
    User.create!(user_name: name, email: email, password: "password123")
  end

  def create_package(attrs = {})
    WinePackage.create!(
      {
        producer: producer,
        reviewer: reviewer,
        created_by: reviewer,
        source: "unexpected",
        status: "announced"
      }.merge(attrs)
    )
  end

  describe "validations and defaults" do
    it "defaults to the manual provider" do
      tracking = ShipmentTracking.new(wine_package: package)

      expect(tracking.provider).to eq("manual")
      expect(tracking).to be_valid
    end

    it "requires a package" do
      tracking = ShipmentTracking.new(carrier: "Aramex")

      expect(tracking).not_to be_valid
      expect(tracking.errors[:wine_package]).to be_present
    end

    it "requires a provider" do
      tracking = ShipmentTracking.new(wine_package: package, provider: nil)

      expect(tracking).not_to be_valid
      expect(tracking.errors[:provider]).to be_present
    end

    it "allows only one tracking row per package" do
      ShipmentTracking.create!(wine_package: package, carrier: "Aramex", provider: "manual")

      expect do
        ShipmentTracking.create!(wine_package: package, carrier: "Aramex", provider: "manual")
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "is destroyed with its package" do
      tracking = ShipmentTracking.create!(wine_package: package, provider: "manual")

      package.destroy

      expect(ShipmentTracking.exists?(tracking.id)).to be false
    end
  end

  describe "provider resolution" do
    it "resolves the manual provider" do
      tracking = ShipmentTracking.new(wine_package: package, provider: "manual")

      expect(tracking.provider_impl).to be_a(TrackingProvider::Manual)
      expect(tracking.provider_impl.configured?).to be true
    end

    it "infers Australia Post from the carrier name" do
      tracking = ShipmentTracking.create!(wine_package: package, carrier: "Australia Post",
                                          number: "AP1")

      expect(tracking.provider).to eq("australia_post")
      expect(tracking.provider_impl).to be_a(TrackingProvider::AustraliaPost)
    end

    it "leaves an unknown carrier on the manual provider" do
      tracking = ShipmentTracking.create!(wine_package: package, carrier: "Aramex")

      expect(tracking.provider).to eq("manual")
    end

    it "keeps an explicitly configured provider when the carrier looks like another" do
      tracking = ShipmentTracking.create!(wine_package: package, carrier: "Aramex",
                                          provider: "australia_post")

      expect(tracking.provider).to eq("australia_post")
    end
  end

  describe "#delivered?" do
    it "is false until the carrier reports delivery" do
      tracking = ShipmentTracking.create!(wine_package: package, provider: "manual")

      expect(tracking.delivered?).to be false
    end

    it "is true once delivered_at is set" do
      tracking = ShipmentTracking.create!(wine_package: package, provider: "manual",
                                          delivered_at: Time.current)

      expect(tracking.delivered?).to be true
    end
  end

  describe "#apply_result!" do
    let(:tracking) do
      ShipmentTracking.create!(wine_package: package, carrier: "Aramex", number: "AR1",
                               provider: "manual", status: "In transit")
    end

    it "applies everything the provider returned" do
      eta = Time.current + 2.days
      delivered = Time.current

      tracking.apply_result!({
        status: "Delivered",
        url: "https://carrier.example/track/AR1",
        status_updated_at: delivered,
        estimated_delivery_at: eta,
        delivered_at: delivered
      })

      tracking.reload
      expect(tracking.status).to eq("Delivered")
      expect(tracking.url).to eq("https://carrier.example/track/AR1")
      expect(tracking.estimated_delivery_at).to be_within(1.second).of(eta)
      expect(tracking.delivered_at).to be_within(1.second).of(delivered)
      expect(tracking.status_updated_at).to be_within(1.second).of(delivered)
    end

    it "accepts string keys" do
      tracking.apply_result!({ "status" => "Awaiting collection" })

      expect(tracking.reload.status).to eq("Awaiting collection")
    end

    it "stamps the check time even when the provider says nothing" do
      tracking.apply_result!({})

      tracking.reload
      expect(tracking.status).to eq("In transit")
      expect(tracking.status_updated_at).to be_present
    end

    it "never wipes what a reviewer already recorded" do
      eta = Time.current + 3.days
      tracking.update!(estimated_delivery_at: eta, delivered_at: Time.current)

      tracking.apply_result!({ events: [] })

      tracking.reload
      expect(tracking.status).to eq("In transit")
      expect(tracking.estimated_delivery_at).to be_within(1.second).of(eta)
      expect(tracking.delivered_at).to be_present
    end

    it "records the provider's events without duplicating them" do
      event = { external_id: "evt-1", status: "Departed", event_at: Time.current,
                location: "Sydney" }

      tracking.apply_result!({ events: [ event ] })
      tracking.apply_result!({ events: [ event ] })

      expect(package.reload.shipment_tracking_events.count).to eq(1)
      expect(package.shipment_tracking_events.first.location).to eq("Sydney")
    end

    it "keeps the package's tracking snapshot in step" do
      tracking.apply_result!({ status: "Out for delivery", url: "https://carrier.example/AR1" })

      package.reload
      expect(package.tracking_carrier).to eq("Aramex")
      expect(package.tracking_number).to eq("AR1")
      expect(package.tracking_url).to eq("https://carrier.example/AR1")
      expect(package.tracking_status).to eq("Out for delivery")
      expect(package.tracking_status_updated_at).to be_present
    end

    it "exposes the event history through the package" do
      tracking.apply_result!({ events: [ { status: "Departed" } ] })

      expect(tracking.shipment_tracking_events.count).to eq(1)
    end
  end

  describe "#refresh!" do
    it "leaves manually maintained tracking untouched with the manual provider" do
      tracking = ShipmentTracking.create!(wine_package: package, carrier: "Aramex",
                                          number: "AR1", provider: "manual",
                                          status: "In transit")

      tracking.refresh!

      tracking.reload
      expect(tracking.status).to eq("In transit")
      expect(tracking.status_updated_at).to be_present
      expect(tracking.shipment_tracking_events.count).to eq(0)
    end

    it "builds the Australia Post tracking URL without any credentials" do
      previous = ENV["AUSTRALIA_POST_API_KEY"]
      ENV.delete("AUSTRALIA_POST_API_KEY")

      tracking = ShipmentTracking.create!(wine_package: package, carrier: "Australia Post",
                                          number: "AP9")

      tracking.refresh!

      tracking.reload
      expect(tracking.url).to include("AP9")
      expect(tracking.provider_impl.configured?).to be false
      expect(tracking.shipment_tracking_events.count).to eq(0)
    ensure
      ENV["AUSTRALIA_POST_API_KEY"] = previous if previous
    end
  end

  describe "carrier delivery" do
    it "never marks the package as arrived" do
      arrived = create_package(status: "announced")
      tracking = ShipmentTracking.create!(wine_package: arrived, carrier: "Aramex",
                                          number: "AR1", provider: "manual")

      tracking.apply_result!({ status: "Delivered", delivered_at: Time.current })

      arrived.reload
      expect(arrived.status).to eq("announced")
      expect(arrived.arrived_at).to be_nil
      expect(arrived.review_deadline).to be_nil
      expect(tracking.reload.delivered?).to be true
    end
  end
end
