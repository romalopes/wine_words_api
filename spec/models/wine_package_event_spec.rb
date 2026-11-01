require "rails_helper"

# Unit specs for WinePackageEvent — one application activity event on a
# package (issue #199 §5).
#
# What matters here: `record!` is idempotent per (package, idempotency_key),
# events carry actor provenance, and the shared/internal visibility boundary
# gates what a producer-side viewer may enumerate (carrier events stay in
# ShipmentTrackingEvent — never duplicated here).
RSpec.describe WinePackageEvent, type: :model do
  let(:producer) { Producer.create!(name: "Timeline Producer") }
  let(:editor)   { create_user("Timeline Editor", "timeline-editor@example.com") }
  let(:member)   { create_user("Timeline Member", "timeline-member@example.com") }

  def create_user(name, email)
    User.create!(first_name: name, email: email, password: "password123")
  end

  def create_package(attrs = {})
    WinePackage.create!(
      {
        producer: producer, reviewer: editor, created_by: editor,
        source: "producer_request", status: "requested",
        requested_at: Time.current, requested_by: member
      }.merge(attrs)
    )
  end

  describe "validations" do
    it "requires an event type" do
      event = WinePackageEvent.new(wine_package: create_package, occurred_at: Time.current)

      expect(event).not_to be_valid
      expect(event.errors[:event_type]).to be_present
    end

    it "requires a package" do
      event = WinePackageEvent.new(event_type: "submitted", occurred_at: Time.current)

      expect(event).not_to be_valid
      expect(event.errors[:wine_package]).to be_present
    end

    it "defaults to shared visibility and current time when omitted" do
      event = WinePackageEvent.new(
        wine_package: create_package, event_type: "submitted", occurred_at: Time.current
      )

      expect(event).to be_valid
      expect(event.visibility).to eq("shared")
    end
  end

  describe ".record!" do
    it "creates the event and stores actor provenance" do
      package = create_package

      event = WinePackageEvent.record!(
        wine_package: package, event_type: "submitted", actor: member,
        metadata: { "source" => "portal" }
      )

      expect(event).to be_persisted
      expect(event.event_type).to eq("submitted")
      expect(event.actor).to eq(member)
      expect(event.metadata).to eq({ "source" => "portal" })
      expect(package.wine_package_events.count).to eq(1)
    end

    it "is idempotent per idempotency_key" do
      package = create_package
      first = WinePackageEvent.record!(
        wine_package: package, event_type: "accepted", actor: editor, idempotency_key: "evt-1"
      )

      second = WinePackageEvent.record!(
        wine_package: package, event_type: "accepted", actor: editor, idempotency_key: "evt-1"
      )

      expect(second.id).to eq(first.id)
      expect(package.wine_package_events.count).to eq(1)
    end

    it "keeps different idempotency keys distinct" do
      package = create_package

      WinePackageEvent.record!(wine_package: package, event_type: "accepted", actor: editor, idempotency_key: "evt-1")
      WinePackageEvent.record!(wine_package: package, event_type: "accepted", actor: editor, idempotency_key: "evt-2")

      expect(package.wine_package_events.count).to eq(2)
    end

    it "always records when no idempotency key is given" do
      package = create_package
      WinePackageEvent.record!(wine_package: package, event_type: "rejected")

      WinePackageEvent.record!(wine_package: package, event_type: "rejected")

      expect(package.wine_package_events.count).to eq(2)
    end

    it "marks editorial decisions internal when asked" do
      package = create_package

      event = WinePackageEvent.record!(
        wine_package: package, event_type: "accepted", actor: editor, visibility: "internal"
      )

      expect(event.internal?).to be(true)
    end
  end

  describe "ordering" do
    it "returns events oldest first" do
      package = create_package
      first = WinePackageEvent.record!(
        wine_package: package, event_type: "submitted", actor: member, occurred_at: 2.hours.ago
      )
      last = WinePackageEvent.record!(wine_package: package, event_type: "withdrawn", actor: member)

      expect(package.wine_package_events.chronological).to eq([ first, last ])
    end
  end

  describe "visibility" do
    it "shows shared events to every viewer who can see the package" do
      package = create_package
      WinePackageEvent.record!(wine_package: package, event_type: "submitted", actor: member, visibility: "shared")

      expect(package.wine_package_events.visible_to(false).count).to eq(1)
    end

    it "hides internal events from producer-side viewers" do
      package = create_package
      WinePackageEvent.record!(wine_package: package, event_type: "accepted", actor: editor, visibility: "internal")

      expect(package.wine_package_events.visible_to(false).count).to eq(0)
    end

    it "shows internal events to editorial viewers" do
      package = create_package
      WinePackageEvent.record!(wine_package: package, event_type: "accepted", actor: editor, visibility: "internal")

      expect(package.wine_package_events.visible_to(true).count).to eq(1)
    end
  end
end
