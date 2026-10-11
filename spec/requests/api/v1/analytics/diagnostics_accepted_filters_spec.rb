require "rails_helper"

RSpec.describe "GET /api/v1/analytics/diagnostics/accepted - Filters", type: :request do
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

  def create_article(user, title: "Test #{SecureRandom.hex(3)}")
    Article.create!(title: title, user: user, status: "published")
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
    create_event("account:#{admin.id}", viewable_id: article.id, viewed_at: 2.days.ago)
    create_event("visitor:#{visitor_id}", viewable_id: article.id, viewed_at: 1.day.ago)
  end

  it "filters by content_type" do
    get "/api/v1/analytics/diagnostics/accepted", params: { content_type: "Article" }
    expect(response.parsed_body["events"].size).to eq(2)
  end

  it "filters by viewable_id" do
    other_article = create_article(admin, title: "Other")
    create_event("account:#{admin.id}", viewable_id: other_article.id)
    get "/api/v1/analytics/diagnostics/accepted", params: { viewable_id: article.id }
    expect(response.parsed_body["events"].size).to eq(2)
  end

  it "filters by date range" do
    get "/api/v1/analytics/diagnostics/accepted", params: {
      start_date: 3.days.ago.iso8601, end_date: 1.hour.ago.iso8601
    }
    expect(response.parsed_body["events"].size).to eq(2)
  end
end