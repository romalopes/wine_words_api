require "rails_helper"

# Unit specs for ShipmentTrackingEvent — the immutable history behind a
# package's shipment. Event imports must be idempotent: re-reading the same
# carrier payload must not duplicate milestones.
RSpec.describe ShipmentTrackingEvent, type: :model do
  let(:producer) { Producer.create!(name: "Phase F Event Producer") }
  let(:reviewer) { create_user("Phase F Event Reviewer", "phase-f-event@example.com") }
  let(:package) { create_package }

  def create_user(name, email)
    User.create!(user_name: name, email: email, password: "password123")
  end

  def create_package
    WinePackage.create!(producer: producer, reviewer: reviewer, created_by: reviewer,
                        source: "unexpected", status: "announced")
  end

  describe "validations and defaults" do
    it "requires a status" do
      event = ShipmentTrackingEvent.new(wine_package: package)

      expect(event).not_to be_valid
      expect(event.errors[:status]).to be_present
    end

    it "requires a package" do
      event = ShipmentTrackingEvent.new(status: "Departed")

      expect(event).not_to be_valid
      expect(event.errors[:wine_package]).to be_present
    end

    it "defaults the raw payload to an empty hash" do
      event = ShipmentTrackingEvent.new(status: "Departed")

      expect(event.raw_data).to eq({})
    end

    it "keeps several events per package" do
      ShipmentTrackingEvent.create!(wine_package: package, status: "Departed")
      ShipmentTrackingEvent.create!(wine_package: package, status: "Arrived at depot")

      expect(package.shipment_tracking_events.count).to eq(2)
    end

    it "is destroyed with its package" do
      event = ShipmentTrackingEvent.create!(wine_package: package, status: "Departed")

      package.destroy

      expect(ShipmentTrackingEvent.exists?(event.id)).to be false
    end
  end

  describe ".record_from_provider!" do
    it "records a normalised provider event" do
      happened_at = Time.current

      event = described_class.record_from_provider!(
        package,
        { external_id: "evt-1", status: "Departed", event_at: happened_at,
          location: "Sydney", message: "Left the facility" }
      )

      expect(event).to be_persisted
      expect(event.wine_package).to eq(package)
      expect(event.external_id).to eq("evt-1")
      expect(event.status).to eq("Departed")
      expect(event.event_at).to be_within(1.second).of(happened_at)
      expect(event.location).to eq("Sydney")
      expect(event.message).to eq("Left the facility")
    end

    it "accepts string keys" do
      event = described_class.record_from_provider!(
        package, { "external_id" => "evt-str", "status" => "In transit" }
      )

      expect(event.status).to eq("In transit")
      expect(event.external_id).to eq("evt-str")
    end

    it "falls back to an unknown status when the payload has none" do
      event = described_class.record_from_provider!(package, { external_id: "evt-no-status" })

      expect(event.status).to eq("unknown")
    end

    it "updates rather than duplicates an event that shares an external id" do
      first = described_class.record_from_provider!(
        package, { external_id: "evt-2", status: "In transit", location: "Sydney" }
      )
      second = described_class.record_from_provider!(
        package, { external_id: "evt-2", status: "Delivered", location: "Melbourne" }
      )

      expect(second.id).to eq(first.id)
      expect(package.shipment_tracking_events.count).to eq(1)
      expect(second.reload.status).to eq("Delivered")
      expect(second.location).to eq("Melbourne")
    end

    it "allows repeated manual events without an external id" do
      described_class.record_from_provider!(package, { status: "Note one" })
      described_class.record_from_provider!(package, { status: "Note two" })

      expect(package.shipment_tracking_events.count).to eq(2)
    end

    it "keeps the untouched provider payload when one is supplied" do
      event = described_class.record_from_provider!(
        package,
        { external_id: "evt-3", status: "In transit", raw_data: { "code" => "X1" } }
      )

      expect(event.raw_data).to eq("code" => "X1")
    end

    it "stores the normalised payload when no raw data is supplied" do
      event = described_class.record_from_provider!(
        package, { external_id: "evt-4", status: "Departed", location: "Sydney" }
      )

      expect(event.raw_data["status"]).to eq("Departed")
      expect(event.raw_data["location"]).to eq("Sydney")
    end
  end

  describe "ordering" do
    it "lists events chronologically" do
      latest = ShipmentTrackingEvent.create!(wine_package: package, status: "Delivered",
                                            event_at: 1.day.ago)
      earliest = ShipmentTrackingEvent.create!(wine_package: package, status: "Departed",
                                              event_at: 3.days.ago)
      middle = ShipmentTrackingEvent.create!(wine_package: package, status: "In transit",
                                            event_at: 2.days.ago)

      expect(package.shipment_tracking_events.chronological.to_a)
        .to eq([ earliest, middle, latest ])
    end
  end
end
