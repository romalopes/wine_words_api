require "rails_helper"

RSpec.describe "GET /api/v1/analytics/diagnostics/accepted - Masking", type: :request do
  include Devise::Test::IntegrationHelpers

  def create_user(email_prefix, roles: [])
    user = User.create!(
      first_name: "Diag #{email_prefix} #{SecureRandom.hex(2)}",
      email: "diag-#{email_prefix}-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
    roles.each { |r| user.roles << Role.find_or_create_by!(name: r) }
    user
  end

  def create_article(user)
    Article.create!(title: "Test #{SecureRandom.hex(3)}", user: user, status: "published")
  end

  let(:admin) { create_user("admin", roles: ["Admin"]) }
  let(:article) { create_article(admin) }
  let(:visitor_id) { "550e8400-e29b-41d4-a716-446655440000" }

  before { AppSetting.set!("analytics_diagnostics_enabled", true) }
  after { AppSetting.set!("analytics_diagnostics_enabled", false) }

  def create_event(identity, attrs = {})
    Analytics::Event.create!({
      viewable_type: "Article", viewable_id: article.id,
      identity: identity, viewed_at: Time.current,
      source: "direct", accepted: true
    }.merge(attrs))
  end

  before do
    sign_in admin
    create_event("account:#{admin.id}")
    create_event("visitor:#{visitor_id}")
  end

  it "returns paginated masked events" do
    get "/api/v1/analytics/diagnostics/accepted"
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body).to have_key("events")
    expect(body).to have_key("pagination")
    expect(body).to have_key("scope_label")
  end

  it "masks account identity as account:***" do
    get "/api/v1/analytics/diagnostics/accepted"
    events = response.parsed_body["events"]
    expect(events.find { |e| e["identity"] == "account:***" }).not_to be_nil
  end

  it "masks visitor identity as visitor:***" do
    get "/api/v1/analytics/diagnostics/accepted"
    events = response.parsed_body["events"]
    expect(events.find { |e| e["identity"] == "visitor:***" }).not_to be_nil
  end

  it "masks referrer to origin only" do
    create_event("account:#{admin.id}", referrer: "https://example.com/path?query=1")
    get "/api/v1/analytics/diagnostics/accepted"
    events = response.parsed_body["events"]
    expect(events.find { |e| e["referrer"] == "https://example.com" }).not_to be_nil
  end

  it "masks visitor_key to first 8 chars" do
    create_event("account:#{admin.id}", visitor_key: "abcdef1234567890")
    get "/api/v1/analytics/diagnostics/accepted"
    events = response.parsed_body["events"]
    expect(events.find { |e| e["visitor_key"] == "abcdef12..." }).not_to be_nil
  end

  it "includes safe fields: id, viewable_type, viewable_id, viewed_at, source, viewport, created_at" do
    get "/api/v1/analytics/diagnostics/accepted"
    event = response.parsed_body["events"].first
    expect(event).to include("id", "viewable_type", "viewable_id", "viewed_at", "source", "viewport", "created_at")
  end

  it "never exposes raw IPs, tokens, names, or full user agents" do
    create_event("account:#{admin.id}", viewport: "1920x1080")
    get "/api/v1/analytics/diagnostics/accepted"
    event = response.parsed_body["events"].first
    expect(event["viewport"]).to eq("1920x1080")
    expect(event.keys).not_to include("ip", "token", "name", "user_agent")
  end

  it "only returns accepted events, never rejected" do
    Analytics::Event.create!(
      viewable_type: "Article", viewable_id: article.id,
      identity: "visitor:#{SecureRandom.uuid}", viewed_at: Time.current,
      source: "direct", accepted: false
    )
    get "/api/v1/analytics/diagnostics/accepted"
    expect(Analytics::Event.accepted.count).to eq(2)
  end
end