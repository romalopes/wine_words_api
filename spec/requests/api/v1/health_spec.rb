require "rails_helper"
require "devise"

# Request specs for Api::V1::HealthController — the public liveness check and
# the admin-gated detailed diagnostic endpoint.
RSpec.describe "Api::V1::Health", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:super_user) do
    User.create!(name: "Super", email: "super@example.com", password: "password123")
  end

  before do
    super_user.roles << Role.find_or_create_by!(name: "Super User")
  end

  describe "GET /api/v1/health" do
    it "is public (no auth required) and returns ok" do
      get "/api/v1/health"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({ "status" => "ok" })
    end

    it "does not leak version, environment or stack details" do
      get "/api/v1/health"
      body = JSON.parse(response.body)
      expect(body.keys).to contain_exactly("status")
    end

    it "returns 503 when the database connection fails" do
      allow(ActiveRecord::Base.connection).to receive(:active?).and_return(false)
      get "/api/v1/health"
      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body)).to eq({ "status" => "error" })
    end
  end

  describe "GET /api/v1/health/detailed" do
    it "requires admin authentication" do
      get "/api/v1/health/detailed"
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a non-admin authenticated user" do
      user = User.create!(name: "Guest", email: "guest@example.com", password: "password123")
      sign_in user
      get "/api/v1/health/detailed"
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in super_user }

      it "returns the detailed payload" do
        get "/api/v1/health/detailed"
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["status"]).to eq("ok")
        expect(body["service"]).to eq("wine-api")
        expect(body["database"]).to eq("ok")
        expect(body["environment"]).to eq(Rails.env)
        expect(body["version"]).to eq("0.0.20")
        expect(body["timestamp"]).to be_present
      end

      it "reports an error status when the database is down" do
        allow(ActiveRecord::Base.connection).to receive(:active?).and_return(false)
        get "/api/v1/health/detailed"
        expect(response).to have_http_status(:service_unavailable)
        body = JSON.parse(response.body)
        expect(body["status"]).to eq("error")
        expect(body["database"]).to eq("error")
      end
    end
  end
end