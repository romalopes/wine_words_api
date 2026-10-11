require "rails_helper"

RSpec.describe Analytics::Ingest do
  include ActiveSupport::Testing::TimeHelpers
  def create_user(email_prefix)
    User.create!(first_name: "Ingest #{email_prefix} #{SecureRandom.hex(2)}",
                 email: "ingest-#{email_prefix}-#{SecureRandom.hex(4)}@example.com",
                 password: "password123")
  end

  let(:owner) { create_user("owner") }
  let(:viewer) { create_user("viewer") }
  let(:article) { Article.create!(title: "Ingest Article #{SecureRandom.hex(3)}", user: owner, status: "published") }
  let(:identity) { "visitor:550e8400-e29b-41d4-a716-446655440000" }

  def attrs(overrides = {})
    {
      event_type: "view",
      content_type: "Article",
      content_id: article.id,
      identity: identity,
      source: "direct"
    }.merge(overrides)
  end

  it "creates an accepted event for valid input" do
    result = described_class.call(**attrs)
    expect(result.success?).to be true
    expect(result.duplicate?).to be false
    expect(Analytics::Event.accepted.count).to eq(1)
  end

  it "rejects invalid event types" do
    result = described_class.call(**attrs(event_type: "click"))
    expect(result.success?).to be false
  end

  it "rejects invalid content types" do
    result = described_class.call(**attrs(content_type: "User"))
    expect(result.success?).to be false
  end

  it "deduplicates a repeat view within the window" do
    described_class.call(**attrs)
    result = described_class.call(**attrs)
    expect(result.success?).to be true
    expect(result.duplicate?).to be true
    expect(Analytics::Event.accepted.count).to eq(1)
  end

  it "accepts a new event after the window expires" do
    travel_to Time.current do
      described_class.call(**attrs)
      travel 31.minutes
      result = described_class.call(**attrs)
      expect(result.success?).to be true
      expect(result.duplicate?).to be false
      expect(Analytics::Event.accepted.count).to eq(2)
    end
  end

  it "silently drops admin views" do
    owner.add_role("Admin")
    result = described_class.call(**attrs(identity: "account:#{owner.id}", current_user: owner))
    expect(result.success?).to be true
    expect(Analytics::Event.accepted.count).to eq(0)
  end

  it "silently drops author self-views" do
    result = described_class.call(**attrs(identity: "account:#{owner.id}", current_user: owner))
    expect(result.success?).to be true
    expect(Analytics::Event.accepted.count).to eq(0)
  end

  it "silently drops opted-out users" do
    viewer.update!(analytics_opt_out: true)
    result = described_class.call(**attrs(identity: "account:#{viewer.id}", current_user: viewer))
    expect(result.success?).to be true
    expect(Analytics::Event.accepted.count).to eq(0)
  end

  it "silently drops inaccessible content" do
    draft = Article.create!(title: "Draft #{SecureRandom.hex(3)}", user: owner, status: "draft")
    result = described_class.call(**attrs(content_id: draft.id,
                                          identity: "account:#{viewer.id}",
                                          current_user: viewer))
    expect(result.success?).to be true
    expect(Analytics::Event.accepted.count).to eq(0)
  end
end
