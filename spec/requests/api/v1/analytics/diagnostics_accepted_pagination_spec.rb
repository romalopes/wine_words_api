require "rails_helper"

RSpec.describe "GET /api/v1/analytics/diagnostics/accepted - Pagination", type: :request do
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
    30.times { |i| create_event("visitor:#{SecureRandom.uuid}") }
  end

  it "defaults to page 1, 25 per page" do
    get "/api/v1/analytics/diagnostics/accepted"
    pagination = response.parsed_body["pagination"]
    expect(pagination["page"]).to eq(1)
    expect(pagination["per_page"]).to eq(25)
    expect(response.parsed_body["events"].size).to eq(25)
  end

  it "respects page parameter" do
    get "/api/v1/analytics/diagnostics/accepted", params: { page: 2 }
    expect(response.parsed_body["pagination"]["page"]).to eq(2)
  end

  it "caps per_page at 50" do
    get "/api/v1/analytics/diagnostics/accepted", params: { per_page: 100 }
    expect(response.parsed_body["pagination"]["per_page"]).to eq(50)
  end

  it "returns correct total_count and total_pages" do
    get "/api/v1/analytics/diagnostics/accepted"
    pagination = response.parsed_body["pagination"]
    expect(pagination["total_count"]).to eq(30)
    expect(pagination["total_pages"]).to eq(2)
  end
end