require "rails_helper"

RSpec.describe Analytics::Event, type: :model do
  let(:visitor_identity) { "visitor:550e8400-e29b-41d4-a716-446655440000" }

  def build_event(overrides = {})
    described_class.new(
      viewable_type: "Article",
      viewable_id: 1,
      identity: visitor_identity,
      viewed_at: Time.current,
      accepted: true
    ).tap { |e| e.assign_attributes(overrides) }
  end

  describe "validations" do
    it "accepts a valid event" do
      expect(build_event).to be_valid
    end

    it "rejects unknown content types" do
      expect(build_event(viewable_type: "User")).not_to be_valid
    end

    it "rejects non-positive content IDs" do
      expect(build_event(viewable_id: 0)).not_to be_valid
    end

    it "rejects malformed identities" do
      expect(build_event(identity: "no-prefix")).not_to be_valid
      expect(build_event(identity: "account:abc")).not_to be_valid
      expect(build_event(identity: "visitor:not-a-uuid")).not_to be_valid
    end

    it "accepts account identities" do
      expect(build_event(identity: "account:42")).to be_valid
    end
  end

  describe "scopes" do
    before do
      described_class.create!(viewable_type: "Article", viewable_id: 1,
                              identity: visitor_identity, viewed_at: Time.current, accepted: true)
      described_class.create!(viewable_type: "Article", viewable_id: 1,
                              identity: "visitor:660e8400-e29b-41d4-a716-446655440001",
                              viewed_at: Time.current, accepted: false)
    end

    it ".accepted returns only accepted events" do
      expect(described_class.accepted.count).to eq(1)
    end

    it ".for_content filters by type and id" do
      expect(described_class.for_content("Article", 1).count).to eq(2)
      expect(described_class.for_content("Review", 1).count).to eq(0)
    end

    it ".for_identity filters by identity" do
      expect(described_class.for_identity(visitor_identity).count).to eq(1)
    end
  end

  describe ".anonymize_account!" do
    it "rewrites account identity to erased form" do
      described_class.create!(viewable_type: "Article", viewable_id: 1,
                              identity: "account:42", viewed_at: Time.current, accepted: true)
      described_class.anonymize_account!(42)
      expect(described_class.where(identity: "visitor:erased-42")).to exist
    end
  end

  describe ".purge_content!" do
    it "deletes events for the content" do
      described_class.create!(viewable_type: "Article", viewable_id: 99,
                              identity: visitor_identity, viewed_at: Time.current, accepted: true)
      described_class.purge_content!("Article", 99)
      expect(described_class.for_content("Article", 99)).to be_empty
    end
  end

  describe ".dedup_lock_key" do
    it "fits in signed 63-bit range" do
      100.times do
        key = described_class.dedup_lock_key("Article", rand(1..9999),
                                             "visitor:#{SecureRandom.uuid}", Time.current)
        expect(key).to be >= 0
        expect(key).to be <= 0x7fffffffffffffff
      end
    end
  end
end
