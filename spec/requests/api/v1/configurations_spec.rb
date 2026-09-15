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
    # Restore the global default so other specs are not affected by the toggle.
    AppSetting.find_by(key: "logs_enabled")&.destroy
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

    it "returns the default logs_saved_to_database = true when unset" do
      sign_in admin
      get "/api/v1/configuration"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({ "logs_saved_to_database" => true })
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