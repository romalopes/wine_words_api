require "rails_helper"
require "devise"

# Request specs for Api::V1::HealthController — the public liveness check and
# the admin-gated detailed diagnostic endpoint.
RSpec.describe "Api::V1::Health", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    User.create!(name: "Admin", email: "admin@example.com", password: "password123")
  end

  before do
    admin.roles << Role.find_or_create_by!(name: "Admin")
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
      before { sign_in admin }

      it "returns the detailed payload" do
        get "/api/v1/health/detailed"
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["status"]).to eq("ok")
        expect(body["service"]).to eq("wine-api")
        expect(body["database"]).to eq("ok")
        expect(body["environment"]).to eq(Rails.env)
        expect(body["version"]).to eq("0.0.21")
        expect(body["timestamp"]).to be_present
      end

      it "returns the detailed payload with database_details, server, and endpoint sections" do
        get "/api/v1/health/detailed"
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)

        # database_details is shaped per db_connection_info in the controller.
        db = body["database_details"]
        expect(db).to be_a(Hash)
        expect(db.keys).to include(
          "adapter", "database", "host", "port", "username",
          "encoding", "pool", "checkout_timeout",
          "reaping_frequency", "idle_timeout"
        )
        expect(db["adapter"]).to be_a(String)
        expect(db["adapter"]).not_to be_empty
        # Postgres is configured in config/database.yml, so this should hold
        # in dev, test, and production (the spec harness uses Postgres too).
        expect(db["adapter"].downcase).to include("postgres")
        expect(db["pool"]).to be_a(Integer).and(be >= 1)

        # server section.
        server = body["server"]
        expect(server).to be_a(Hash)
        expect(server["rails_version"]).to be_a(String)
        expect(server["ruby"]).to be_a(String)
        expect(server["pid"]).to be_a(Integer)
        expect(server.keys).to include("rails_version", "ruby", "puma_workers",
                                       "hostname", "pid", "render")
        expect(server["render"]).to be_in([true, false])

        # endpoint section reflects the actual request.
        endpoint = body["endpoint"]
        expect(endpoint).to be_a(Hash)
        expect(endpoint["scheme"]).to eq("http")
        expect(endpoint["host"]).to be_a(String)
        expect(endpoint["port"]).to be_a(Integer)
        expect(endpoint["base_url"]).to start_with("http://")
        expect(endpoint["path"]).to eq("/api/v1/health/detailed")
      end

      it "reports where uploaded files are stored via storage_details" do
        get "/api/v1/health/detailed"
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)

        storage = body["storage_details"]
        expect(storage).to be_a(Hash)
        expect(storage.keys).to contain_exactly(
          "service", "service_class", "bucket", "region",
          "endpoint", "root", "public"
        )
        # Both S3-family and Disk services expose the symbolic `name` from
        # storage.yml, so this must always be a non-empty string.
        expect(storage["service"]).to be_a(String)
        expect(storage["service"]).not_to be_empty
        expect(storage["service_class"]).to start_with("ActiveStorage::Service::")

        # The remaining fields depend on the configured backend. The test
        # environment uses DiskService (config/environments/test.rb), while
        # dev/prod use the Supabase S3 service — assert whichever shape we get.
        if storage["service_class"].end_with?("DiskService")
          expect(storage["root"]).to be_a(String)
          expect(storage["root"]).not_to be_empty
        elsif storage["service_class"].end_with?("S3Service")
          expect(storage["bucket"]).to be_a(String)
          expect(storage["bucket"]).not_to be_empty
        end

        # The bucket name / root path identifies *where* files live — that is
        # the whole point of this section — so at least one must be present.
        expect([storage["bucket"], storage["root"]].compact).not_to be_empty
      end

      it "reports an error status when the database is down" do
        allow(ActiveRecord::Base.connection).to receive(:active?).and_return(false)
        get "/api/v1/health/detailed"
        expect(response).to have_http_status(:service_unavailable)
        body = JSON.parse(response.body)
        expect(body["status"]).to eq("error")
        expect(body["database"]).to eq("error")
      end

      it "still serializes the new sections with nil db details when the database is down" do
        # Connection details should fail safely (returning a hash of nils) so
        # admins can still see server/endpoint info even when the DB is gone.
        # The headline status flips to 503 (DB is the headline check), but the
        # body should still serialize the new sections without 500ing.
        allow(ActiveRecord::Base.connection).to receive(:active?).and_return(false)
        allow(ActiveRecord::Base).to receive(:connection_db_config).and_raise(StandardError, "boom")
        get "/api/v1/health/detailed"
        expect(response).to have_http_status(:service_unavailable)
        body = JSON.parse(response.body)
        expect(body["database_details"]).to be_a(Hash)
        expect(body["database_details"]["adapter"]).to be_nil
        expect(body["server"]).to be_a(Hash)
        expect(body["endpoint"]).to be_a(Hash)
      end
    end
  end
end