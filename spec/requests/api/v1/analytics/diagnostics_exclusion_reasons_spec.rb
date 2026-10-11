require "rails_helper"

RSpec.describe "GET /api/v1/analytics/diagnostics/exclusion_reasons", type: :request do
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
  let(:regular_user) { create_user("user") }
  let(:article) { create_article(admin) }

  before { AppSetting.set!("analytics_diagnostics_enabled", true) }
  after { AppSetting.set!("analytics_diagnostics_enabled", false) }

  def create_rejected_event(reason = "dedup_window")
    Analytics::Event.create!(
      viewable_type: "Article", viewable_id: article.id,
      identity: "visitor:#{SecureRandom.uuid}", viewed_at: Time.current,
      source: "direct", accepted: false, rejection_reason: reason
    )
  end

  context "authorization" do
    it "requires authentication" do
      get "/api/v1/analytics/diagnostics/exclusion_reasons"
      expect(response).to have_http_status(:unauthorized)
    end

    it "requires admin role" do
      sign_in regular_user
      get "/api/v1/analytics/diagnostics/exclusion_reasons"
      expect(response).to have_http_status(:forbidden)
    end

    it "allows admin when enabled" do
      sign_in admin
      get "/api/v1/analytics/diagnostics/exclusion_reasons"
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 when disabled for admin" do
      AppSetting.set!("analytics_diagnostics_enabled", false)
      sign_in admin
      get "/api/v1/analytics/diagnostics/exclusion_reasons"
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "response structure" do
    before do
      sign_in admin
      create_rejected_event("dedup_window")
      create_rejected_event("opt_out")
      create_rejected_event("dedup_window")
    end

    it "returns exclusion reasons with total_rejected count" do
      get "/api/v1/analytics/diagnostics/exclusion_reasons"
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to have_key("exclusion_reasons")
      expect(body).to have_key("scope_label")
    end

    it "includes total_rejected in exclusion_reasons" do
      get "/api/v1/analytics/diagnostics/exclusion_reasons"
      reasons = response.parsed_body["exclusion_reasons"]
      expect(reasons["total_rejected"]).to eq(3)
    end

    it "includes note about future enhancement" do
      get "/api/v1/analytics/diagnostics/exclusion_reasons"
      reasons = response.parsed_body["exclusion_reasons"]
      expect(reasons["note"]).to include("Detailed rejection reasons not yet persisted")
    end

    it "filters by date range" do
      old_event = create_rejected_event("invalid_payload")
      old_event.update!(viewed_at: 10.days.ago)

      get "/api/v1/analytics/diagnostics/exclusion_reasons", params: {
        start_date: 5.days.ago.iso8601, end_date: Time.current.iso8601
      }
      reasons = response.parsed_body["exclusion_reasons"]
      expect(reasons["total_rejected"]).to eq(3)
    end
  end
end