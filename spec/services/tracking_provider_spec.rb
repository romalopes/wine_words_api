require "rails_helper"

# Unit specs for TrackingProvider — carrier-independent shipment tracking.
#
# The provider contract has to hold up without any carrier account, so the
# Australia Post payload mapping is exercised offline.
RSpec.describe TrackingProvider do
  let(:provider) { TrackingProvider::AustraliaPost.new }

  describe ".key_for" do
    it "recognises the Australia Post carrier however it is written" do
      [ "australia_post", "Australia Post", "AUSPost", "aus_post", "Australia-Post" ].each do |name|
        expect(described_class.key_for(name)).to eq("australia_post"), "#{name.inspect} failed"
      end
    end

    it "keeps every other carrier on the manual provider" do
      [ "Aramex", "DHL", "StarTrack", "", nil, "unknown" ].each do |name|
        expect(described_class.key_for(name)).to eq("manual"), "#{name.inspect} failed"
      end
    end
  end

  describe ".for" do
    it "resolves the Australia Post provider" do
      expect(described_class.for("Australia Post")).to be_a(TrackingProvider::AustraliaPost)
    end

    it "falls back to the manual provider" do
      expect(described_class.for("Aramex")).to be_a(TrackingProvider::Manual)
      expect(described_class.for(nil)).to be_a(TrackingProvider::Manual)
    end

    it "lists both providers in its registry" do
      expect(described_class.registry.keys).to match_array([ "manual", "australia_post" ])
    end
  end

  describe TrackingProvider::Manual do
    let(:manual) { described_class.new }

    it "is always available" do
      expect(manual.key).to eq("manual")
      expect(manual.configured?).to be true
    end

    it "fetches nothing, leaving what the reviewer recorded authoritative" do
      expect(manual.track("AR1")).to eq(events: [])
    end
  end

  describe TrackingProvider::AustraliaPost do
    it "reports itself unconfigured without an API key" do
      previous = ENV["AUSTRALIA_POST_API_KEY"]
      ENV.delete("AUSTRALIA_POST_API_KEY")

      expect(described_class.configured?).to be false
      expect(described_class.api_key).to be_nil
    ensure
      ENV["AUSTRALIA_POST_API_KEY"] = previous if previous
    end

    it "builds a human tracking URL from the consignment number" do
      expect(provider.tracking_url("AP123"))
        .to eq("https://auspost.com.au/mypost/track/#/details/AP123")
    end

    it "has no tracking URL without a number" do
      expect(provider.tracking_url(nil)).to be_nil
      expect(provider.tracking_url("")).to be_nil
    end

    it "still returns the tracking URL when no credentials are configured" do
      previous = ENV["AUSTRALIA_POST_API_KEY"]
      ENV.delete("AUSTRALIA_POST_API_KEY")

      result = provider.track("AP123")

      expect(result[:url]).to include("AP123")
      expect(result[:events]).to eq([])
      expect(result[:status]).to be_nil
    ensure
      ENV["AUSTRALIA_POST_API_KEY"] = previous if previous
    end

    it "returns nothing at all without a number" do
      expect(provider.track(nil)).to eq(events: [], url: nil)
    end
  end

  describe "TrackingProvider::AustraliaPost#normalize" do
    let(:payload) do
      {
        "tracking_results" => [ {
          "tracking_id" => "AP123",
          "status" => "Delivered",
          "estimated_delivery_date" => "2026-01-04T00:00:00+11:00",
          "consignments" => [ { "events" => [
            { "date" => "2026-01-02T09:00:00+11:00", "location" => "Sydney",
              "description" => "In transit" },
            { "id" => "evt-delivered", "date" => "2026-01-03T14:00:00+11:00",
              "location" => "Melbourne", "description" => "Delivered" }
          ] } ]
        } ]
      }
    end

    it "maps status, events and the URL onto the normalised contract" do
      result = provider.normalize(payload, "AP123")

      expect(result[:status]).to eq("Delivered")
      expect(result[:url]).to include("AP123")
      expect(result[:events].size).to eq(2)
      expect(result[:status_updated_at]).to be_present
      expect(result[:estimated_delivery_at]).to be_present
    end

    it "derives delivered_at from a delivered status" do
      result = provider.normalize(payload, "AP123")

      expect(result[:delivered_at]).to be_present
    end

    it "keeps the carrier's event id and fingerprints the ones without one" do
      events = provider.normalize(payload, "AP123")[:events]

      expect(events.last[:external_id]).to eq("evt-delivered")
      expect(events.first[:external_id]).to be_present
      expect(events.first[:status]).to eq("In transit")
      expect(events.first[:raw_data]).to include("location" => "Sydney")
    end

    it "produces the same fingerprint for the same event" do
      first = provider.normalize(payload, "AP123")[:events].first
      second = provider.normalize(payload, "AP123")[:events].first

      expect(first[:external_id]).to eq(second[:external_id])
    end

    it "has no delivered_at when the carrier has not delivered" do
      in_transit = { "tracking_results" => [ { "status" => "In transit", "consignments" => [] } ] }

      result = provider.normalize(in_transit, "AP123")

      expect(result[:status]).to eq("In transit")
      expect(result[:delivered_at]).to be_nil
      expect(result[:events]).to eq([])
    end

    it "tolerates an empty or unexpected payload" do
      [ {}, nil, { "tracking_results" => [] }, { "tracking_results" => nil } ].each do |input|
        result = provider.normalize(input, "AP123")

        expect(result[:status]).to be_nil
        expect(result[:events]).to eq([])
      end
    end
  end
end
