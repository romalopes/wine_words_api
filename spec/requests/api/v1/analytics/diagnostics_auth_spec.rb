require "rails_helper"

RSpec.describe "Analytics Diagnostics Authorization", type: :request do
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

  shared_examples "admin-only when enabled" do |endpoint|
    it "requires authentication" do
      get endpoint
      expect(response).to have_http_status(:unauthorized)
    end

    it "requires admin role" do
      sign_in regular_user
      get endpoint
      expect(response).to have_http_status(:forbidden)
    end

    it "allows admin when enabled" do
      sign_in admin
      get endpoint
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 when disabled for admin" do
      AppSetting.set!("analytics_diagnostics_enabled", false)
      sign_in admin
      get endpoint
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error"]).to eq("Diagnostics disabled")
    end
  end

  describe "GET /api/v1/analytics/diagnostics/accepted" do
    include_examples "admin-only when enabled", "/api/v1/analytics/diagnostics/accepted"
  end

  describe "GET /api/v1/analytics/diagnostics/exclusion_reasons" do
    include_examples "admin-only when enabled", "/api/v1/analytics/diagnostics/exclusion_reasons"
  end
end