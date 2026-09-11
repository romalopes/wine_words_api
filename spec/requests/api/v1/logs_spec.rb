require "rails_helper"
require "devise"

RSpec.describe "Api::V1::Logs", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    user = User.create!(user_name: "Admin", email: "admin@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end

  let(:reader) do
    User.create!(user_name: "Reader", email: "reader@example.com", password: "password123")
  end

  let(:other_user) do
    User.create!(user_name: "Other", email: "other@example.com", password: "password123")
  end

  describe "GET /api/v1/logs" do
    context "as an admin" do
      before { sign_in admin }

      it "returns 200 with a logs array" do
        get "/api/v1/logs"
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["logs"]).to be_an(Array)
      end

      it "returns at most the requested number of lines" do
        get "/api/v1/logs?lines=5"
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["logs"].length).to be <= 5
      end
    end

    context "as a non-admin user" do
      before { sign_in reader }

      it "returns 403 forbidden" do
        get "/api/v1/logs"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get "/api/v1/logs"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/logs/audit" do
    context "as an admin" do
      before { sign_in admin }

      it "returns the paginated envelope with the seeded audit entries" do
        LogService.log(description: "Created wine", action: "create", user: admin)

        get "/api/v1/logs/audit", params: { page: 1, per_page: 20 }
        body = JSON.parse(response.body)

        expect(response).to have_http_status(:ok)
        expect(body).to include("items", "page", "per_page", "total_count", "total_pages")
        entry = body["items"].find { |l| l["description"] == "Created wine" }
        expect(entry).to be_present
        expect(entry["action"]).to eq("create")
        expect(entry["user"]["user_name"]).to eq("Admin")
      end

      it "returns a plain array ordered newest-first when no page param is given" do
        Log.create!(description: "Old entry", action: "create", created_at: 3.days.ago)
        LogService.log(description: "New entry", action: "create", user: admin)

        get "/api/v1/logs/audit"
        body = JSON.parse(response.body)

        expect(response).to have_http_status(:ok)
        expect(body).to be_an(Array)
        descriptions = body.map { |l| l["description"] }
        expect(descriptions.index("New entry")).to be < descriptions.index("Old entry")
      end

      it "filters by action" do
        LogService.log(description: "Deleted producer", action: "destroy", user: admin)
        LogService.log(description: "Updated wine", action: "update", user: admin)

        get "/api/v1/logs/audit", params: { action: "destroy", page: 1 }
        body = JSON.parse(response.body)

        expect(body["items"].map { |l| l["action"] }).to all(eq("destroy"))
        expect(body["items"].map { |l| l["description"] }).to include("Deleted producer")
      end

      it "filters by user" do
        LogService.log(description: "Admin did a thing", action: "create", user: admin)
        LogService.log(description: "Other did a thing", action: "create", user: other_user)

        get "/api/v1/logs/audit", params: { user_id: other_user.id, page: 1 }
        body = JSON.parse(response.body)

        expect(body["items"]).not_to be_empty
        expect(body["items"].map { |l| l["description"] }).to all(eq("Other did a thing"))
      end

      it "filters by object type and object id" do
        producer = Producer.create!(name: "Penfolds", slug: "penfolds")
        LogService.log(description: "Updated producer", action: "update", user: admin, objects: [producer])
        LogService.log(description: "Unrelated entry", action: "create", user: admin)

        get "/api/v1/logs/audit",
            params: { object_type: "Producer", object_id: producer.id, page: 1 }
        body = JSON.parse(response.body)

        expect(body["items"].map { |l| l["description"] }).to eq(["Updated producer"])
      end

      it "filters by request id" do
        LogService.log(description: "Correlated entry", action: "update", user: admin, request_id: "req-123")
        LogService.log(description: "Other request", action: "update", user: admin)

        get "/api/v1/logs/audit", params: { request_id: "req-123", page: 1 }

        body = JSON.parse(response.body)

        expect(body["items"].map { |l| l["description"] }).to eq(["Correlated entry"])
      end

      it "filters by date range" do
        Log.create!(description: "Old entry", action: "create", created_at: 3.days.ago)
        LogService.log(description: "Recent entry", action: "create", user: admin)

        get "/api/v1/logs/audit", params: { date_from: 1.day.ago.to_date.iso8601 }
        descriptions = JSON.parse(response.body).map { |l| l["description"] }
        expect(descriptions).to include("Recent entry")
        expect(descriptions).not_to include("Old entry")

        get "/api/v1/logs/audit", params: { date_to: 2.days.ago.to_date.iso8601 }
        descriptions = JSON.parse(response.body).map { |l| l["description"] }
        expect(descriptions).to include("Old entry")
        expect(descriptions).not_to include("Recent entry")
      end

      it "searches description, action and path" do
        LogService.log(description: 'Updated wine "Grange 2021"', action: "update", user: admin)
        LogService.log(description: "Deleted producer", action: "destroy", user: admin)

        get "/api/v1/logs/audit", params: { search: "grange" }

        expect(JSON.parse(response.body).map { |l| l["description"] })
          .to eq(['Updated wine "Grange 2021"'])
      end

      it "respects per_page" do
        LogService.log(description: "Entry A", action: "create", user: admin)
        LogService.log(description: "Entry B", action: "create", user: admin)

        get "/api/v1/logs/audit", params: { page: 1, per_page: 1 }
        body = JSON.parse(response.body)

        expect(body["items"].length).to eq(1)
        expect(body["total_pages"]).to be >= 2
      end

      it "ignores invalid date values instead of failing" do
        LogService.log(description: "Entry", action: "create", user: admin)

        get "/api/v1/logs/audit", params: { date_from: "not-a-date", date_to: "not-a-date" }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).map { |l| l["description"] }).to include("Entry")
      end
    end

    context "as a non-admin user" do
      before { sign_in reader }

      it "returns 403 forbidden" do
        get "/api/v1/logs/audit"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get "/api/v1/logs/audit"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/logs/:id" do
    before { sign_in admin }

    it "returns the log with its objects and alive flags" do
      producer = Producer.create!(name: "Penfolds", slug: "penfolds")
      log = LogService.log(
        description: "Updated producer",
        action: "update",
        user: admin,
        method: "PATCH",
        path: "/api/v1/producers/#{producer.slug}",
        status: 200,
        request_id: "req-1",
        ip_address: "127.0.0.1",
        objects: [producer, ["Producer", 424_242, "Deleted Producer"]]
      )

      get "/api/v1/logs/#{log.id}"
      body = JSON.parse(response.body)

      expect(response).to have_http_status(:ok)
      expect(body["description"]).to eq("Updated producer")
      expect(body["method"]).to eq("PATCH")
      expect(body["user"]["user_name"]).to eq("Admin")
      expect(body["objects"]).to contain_exactly(
        hash_including("type" => "Producer", "id" => producer.id, "label" => "Penfolds", "alive" => true),
        hash_including("type" => "Producer", "id" => 424_242, "label" => "Deleted Producer", "alive" => false)
      )
    end

    it "returns 404 for an unknown log" do
      get "/api/v1/logs/999999"
      expect(response).to have_http_status(:not_found)
    end
  end
end
