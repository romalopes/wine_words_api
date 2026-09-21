require "rails_helper"
require "devise"

RSpec.describe "Api::V1::Configurations", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    user = User.create!(user_name: "CfgAdmin", email: "cfg-admin@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end

  let(:plain_user) do
    User.create!(user_name: "CfgGuest", email: "cfg-guest@example.com", password: "password123")
  end

  after do
    # Restore the global defaults so other specs are not affected by the toggles.
    AppSetting.where(key: %w[logs_enabled use_test_email test_email]).destroy_all
  end

  describe "GET /api/v1/configuration" do
    it "requires authentication" do
      get "/api/v1/configuration"
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a non-admin authenticated user" do
      sign_in plain_user
      get "/api/v1/configuration"
      expect(response).to have_http_status(:forbidden)
    end

    it "returns the defaults when unset" do
      sign_in admin
      get "/api/v1/configuration"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({
        "logs_saved_to_database" => true,
        "use_test_email" => false,
        "test_email" => "romalopes@yahoo.com.br",
        "settings" => []
      })
    end
  end

  describe "PATCH /api/v1/configuration" do
    it "requires authentication" do
      patch "/api/v1/configuration", params: { logs_saved_to_database: false }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a non-admin authenticated user" do
      sign_in plain_user
      patch "/api/v1/configuration", params: { logs_saved_to_database: false }, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "persists the toggle and echoes it back" do
      sign_in admin
      patch "/api/v1/configuration", params: { logs_saved_to_database: false }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["logs_saved_to_database"]).to be(false)
      expect(AppSetting.logs_enabled?).to be(false)

      patch "/api/v1/configuration", params: { logs_saved_to_database: true }, as: :json
      expect(JSON.parse(response.body)["logs_saved_to_database"]).to be(true)
      expect(AppSetting.logs_enabled?).to be(true)
    end

    it "accepts a nested configuration payload (no unpermitted-parameter warning)" do
      sign_in admin
      allow(Rails.logger).to receive(:warn)

      patch "/api/v1/configuration",
            params: { configuration: { logs_saved_to_database: false } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["logs_saved_to_database"]).to be(false)
      expect(AppSetting.logs_enabled?).to be(false)
      expect(Rails.logger).not_to have_received(:warn).with(a_string_including("Unpermitted parameter"))
    end

    it "persists the email test settings and echoes them back" do
      sign_in admin
      patch "/api/v1/configuration",
            params: { use_test_email: true, test_email: "tester@example.com" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["use_test_email"]).to be(true)
      expect(JSON.parse(response.body)["test_email"]).to eq("tester@example.com")
      expect(AppSetting.use_test_email?).to be(true)
      expect(AppSetting.test_email).to eq("tester@example.com")
    end

    it "persists email test settings sent nested under configuration" do
      sign_in admin
      patch "/api/v1/configuration",
            params: { configuration: { use_test_email: true,
                                       test_email: "nested@example.com" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["use_test_email"]).to be(true)
      expect(AppSetting.use_test_email?).to be(true)
      expect(AppSetting.test_email).to eq("nested@example.com")
    end

    it "leaves settings untouched when their keys are absent" do
      sign_in admin
      patch "/api/v1/configuration", params: { use_test_email: true }, as: :json
      expect(AppSetting.logs_enabled?).to be(true) # default, never set
    end

    it "suppresses audit log persistence while disabled and restores it when re-enabled" do
      sign_in admin
      expect {
        patch "/api/v1/account", params: { user_name: "cfg_admin_x" }, as: :json
      }.to change(Log, :count).by(1)

      patch "/api/v1/configuration", params: { logs_saved_to_database: false }, as: :json

      expect {
        patch "/api/v1/account", params: { user_name: "cfg_admin_y" }, as: :json
      }.not_to change(Log, :count)

      patch "/api/v1/configuration", params: { logs_saved_to_database: true }, as: :json

      expect {
        patch "/api/v1/account", params: { user_name: "cfg_admin_z" }, as: :json
      }.to change(Log, :count).by(1)
    end
  end
end