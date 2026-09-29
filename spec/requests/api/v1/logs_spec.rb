require "rails_helper"

# Request specs for Api::V1::LogsController — the admin-only log viewer that
# exposes both the raw Rails log file tail and the database audit trail.
RSpec.describe "Api::V1::Logs", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    User.create!(
      user_name: "Admin",
      email: "admin@example.com",
      password: "password123"
    )
  end

  before do
    admin.roles << Role.find_or_create_by!(name: "Admin")
  end

  let!(:producer) do
    Producer.create!(
      name: "Test Producer",
      # Country requires a 2-letter ISO code.
      country: Country.create!(name: "Australia", code: "AU")
    )
  end

  # `producer` must be declared first: Wine's belongs_to :producer is required,
  # and eager `let!` blocks run in definition order.
  let!(:wine) do
    Wine.create!(
      name: "Test Wine",
      color: "Red",
      prompt: "x",
      producer: producer
    )
  end

  # GET /api/v1/logs — raw log file tail
  describe "GET /api/v1/logs" do
    it "requires authentication" do
      get "/api/v1/logs"
      expect(response).to have_http_status(:unauthorized)
      # Only the status is asserted: an unauthenticated request is stopped by the
      # Devise/Warden failure app, which answers with its own HTML body before
      # the controller's `render json: { error: ... }` can run. Same convention
      # as the health diagnostics specs.
    end

    it "rejects a non-admin authenticated user" do
      user = User.create!(user_name: "Guest", email: "guest@example.com", password: "password123")
      sign_in user
      get "/api/v1/logs"
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)).to eq({ "error" => "Forbidden" })
    end

    context "as an admin" do
      before { sign_in admin }

      it "returns a { logs: [...] } envelope" do
        get "/api/v1/logs"
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to be_a(Hash)
        expect(body["logs"]).to be_a(Array)
      end

      it "accepts a custom line count via ?lines=N" do
        get "/api/v1/logs", params: { lines: 10 }
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["logs"]).to be_a(Array)
      end

      it "clamps lines <= 0 to 500" do
        # The outer describe takes a string, so `described_class` is nil here —
        # name the controller explicitly.
        allow_any_instance_of(Api::V1::LogsController).to receive(:recent_log_lines).with(500).and_return(["line1", "line2"])
        get "/api/v1/logs", params: { lines: 0 }
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["logs"]).to eq(["line1", "line2"])
      end
    end
  end

  # GET /api/v1/logs/audit — paginated, filterable audit trail
  describe "GET /api/v1/logs/audit" do
    it "requires authentication" do
      get "/api/v1/logs/audit"
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a non-admin authenticated user" do
      user = User.create!(user_name: "Guest", email: "guest@example.com", password: "password123")
      sign_in user
      get "/api/v1/logs/audit"
      expect(response).to have_http_status(:forbidden)
    end
  end
end
