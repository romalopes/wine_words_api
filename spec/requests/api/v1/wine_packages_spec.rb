require "rails_helper"

# Request specs for Api::V1::WinePackagesController — the API the React
# wine-packages screens consume. Covers authorization, the create entry points
# (draft/announced/requested/arrived), the workflow actions, filtering and the
# serializer contract. Each example runs in a rolled-back transaction.
RSpec.describe "Api::V1::WinePackages", type: :request do
  include Devise::Test::IntegrationHelpers

  def user_with_role(role_name, user_name, email)
    user = User.create!(user_name: user_name, email: email, password: "password123")
    user.roles << Role.find_or_create_by!(name: role_name)
    user
  end

  let(:producer) { Producer.create!(name: "Penfolds") }
  let(:admin) { user_with_role("Admin", "Package Admin", "package-admin@example.com") }
  # The Reviewer role may record packages but only manages its own.
  let(:reviewer_user) { user_with_role("Reviewer", "Package Reviewer", "package-reviewer@example.com") }
  let(:outsider) { User.create!(user_name: "Package Outsider", email: "package-outsider@example.com", password: "password123") }

  def create_package(overrides = {})
    WinePackage.create!({
      producer: producer,
      reviewer: admin,
      created_by: admin,
      source: "unexpected"
    }.merge(overrides))
  end

  describe "authentication" do
    it "requires a signed-in user" do
      get "/api/v1/wine_packages"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/wine_packages" do
    before { sign_in admin }

    it "records a received package: arrived today, deadline one month later, reminders scheduled" do
      post "/api/v1/wine_packages", as: :json, params: {
        wine_package: { producer_id: producer.id, source: "unexpected",
                        status: "arrived", notes: "Left at reception" }
      }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("arrived")
      expect(body["source"]).to eq("unexpected")
      expect(body["arrived_at"]).to be_present
      expect(body["review_deadline"]).to eq(Date.current.>>(1).iso8601)
      expect(body["reviewer_id"]).to eq(admin.id)
      expect(body["can"]["mark_completed"]).to be true

      package = WinePackage.find(body["id"])
      expect(package.arrived_at.to_date).to eq(Date.current)
      expect(Notification.where(wine_package: package).count).to eq(3)
      expect(Notification.where(wine_package: package).pluck(:notification_type).uniq)
        .to eq([ "wine_package_deadline" ])
    end

    it "adds an expected package as announced (no deadline, no reminders)" do
      post "/api/v1/wine_packages", as: :json, params: {
        wine_package: { producer_id: producer.id, status: "announced",
                        expected_at: (Date.current + 10).iso8601 }
      }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("announced")
      expect(body["announced_at"]).to be_present
      expect(body["expected_at"]).to eq((Date.current + 10).iso8601)
      expect(body["review_deadline"]).to be_nil
      expect(Notification.where(wine_package_id: body["id"]).count).to eq(0)
    end

    it "records a producer request as requested" do
      post "/api/v1/wine_packages", as: :json, params: {
        wine_package: { producer_id: producer.id, source: "producer_request",
                        status: "requested" }
      }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("requested")
      expect(body["requested_at"]).to be_present
      expect(body["can"]["accept"]).to be true
      expect(body["can"]["reject"]).to be true
    end

    it "defaults to draft when no status is given" do
      post "/api/v1/wine_packages", as: :json, params: {
        wine_package: { producer_id: producer.id }
      }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["status"]).to eq("draft")
    end

    it "rejects a status that is not a valid entry point" do
      post "/api/v1/wine_packages", as: :json, params: {
        wine_package: { producer_id: producer.id, status: "completed" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"].first).to include("status must be one of")
      expect(WinePackage.count).to eq(0)
    end

    it "rejects a status that is never assignable at creation" do
      post "/api/v1/wine_packages", as: :json, params: {
        wine_package: { producer_id: producer.id, status: "bogus" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(WinePackage.count).to eq(0)
    end

    it "returns validation errors for a missing producer" do
      post "/api/v1/wine_packages", as: :json, params: {
        wine_package: { notes: "no producer" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to be_present
    end

    context "as a Reviewer (not an Admin/Editor)" do
      before { sign_in reviewer_user }

      it "may record a package and becomes its reviewer" do
        post "/api/v1/wine_packages", as: :json, params: {
          wine_package: { producer_id: producer.id, status: "arrived" }
        }

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["reviewer_id"]).to eq(reviewer_user.id)
        expect(body["created_by_id"]).to eq(reviewer_user.id)
      end
    end

    context "as a user holding no content role" do
      before { sign_in outsider }

      it "is forbidden" do
        post "/api/v1/wine_packages", as: :json, params: {
          wine_package: { producer_id: producer.id }
        }

        expect(response).to have_http_status(:forbidden)
        expect(WinePackage.count).to eq(0)
      end
    end
  end

  describe "GET /api/v1/wine_packages" do
    let!(:mine) { create_package(reviewer: reviewer_user, created_by: reviewer_user, status: "arrived", arrived_at: Time.current, review_deadline: Date.current + 20) }
    let!(:other) { create_package(status: "announced") }

    it "shows every package to a content manager" do
      sign_in admin
      get "/api/v1/wine_packages"

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).map { |p| p["id"] }
      expect(ids).to include(mine.id, other.id)
    end

    it "shows only its own packages to the responsible reviewer" do
      sign_in reviewer_user
      get "/api/v1/wine_packages"

      ids = JSON.parse(response.body).map { |p| p["id"] }
      expect(ids).to eq([ mine.id ])
    end

    it "returns the paginated envelope when page is given" do
      sign_in admin
      get "/api/v1/wine_packages", params: { page: 1, per_page: 1 }

      body = JSON.parse(response.body)
      expect(body.keys).to include("items", "page", "per_page", "total_count", "total_pages")
      expect(body["items"].length).to eq(1)
      expect(body["total_count"]).to eq(2)
      expect(body["total_pages"]).to eq(2)
    end

    it "filters by status" do
      sign_in admin
      get "/api/v1/wine_packages", params: { status: "announced" }

      ids = JSON.parse(response.body).map { |p| p["id"] }
      expect(ids).to eq([ other.id ])
    end

    it "filters overdue packages and exposes the countdown in the serializer" do
      overdue = create_package(status: "arrived", arrived_at: 60.days.ago, review_deadline: 30.days.ago.to_date)
      sign_in admin
      get "/api/v1/wine_packages", params: { overdue: "true" }

      ids = JSON.parse(response.body).map { |p| p["id"] }
      expect(ids).to include(overdue.id)
      expect(ids).not_to include(mine.id)
    end

    it "filters by producer, source and query" do
      sign_in admin
      get "/api/v1/wine_packages", params: { producer_id: producer.id }
      expect(JSON.parse(response.body).length).to eq(2)

      get "/api/v1/wine_packages", params: { source: "unexpected" }
      expect(JSON.parse(response.body).length).to eq(2)

      get "/api/v1/wine_packages", params: { query: "Penfolds" }
      expect(JSON.parse(response.body).length).to eq(2)
    end

    it "serializes the list contract" do
      sign_in admin
      get "/api/v1/wine_packages"

      item = JSON.parse(response.body).find { |p| p["id"] == mine.id }
      expect(item).to include(
        "producer_name" => "Penfolds",
        "status" => "arrived",
        "source" => "unexpected",
        "review_deadline" => (Date.current + 20).iso8601,
        "items_count" => 0,
        "pending_review_count" => 0,
        "overdue" => false
      )
      expect(item["review_progress"]).to eq("requested" => 0, "reviewed" => 0, "pending" => 0, "percent" => 100)
      expect(item["days_until_deadline"]).to eq(20)
    end
  end

  describe "GET /api/v1/wine_packages/:id" do
    let!(:package) { create_package(status: "arrived", arrived_at: Time.current, review_deadline: Date.current + 10) }

    it "returns the detail contract" do
      sign_in admin
      get "/api/v1/wine_packages/#{package.id}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to include(
        "id" => package.id,
        "producer_name" => "Penfolds",
        "status" => "arrived",
        "auto_completed" => false,
        "pending_review_count" => 0,
        "reviews_complete" => true,
        "overdue" => false
      )
      expect(body["items"]).to eq([])
      expect(body["review_progress"]).to eq("requested" => 0, "reviewed" => 0, "pending" => 0, "percent" => 100)
      expect(body["tracking"]).to include("carrier" => nil, "number" => nil, "status" => nil)
      expect(body["can"]).to include("mark_completed" => true, "reopen" => false, "accept" => false)
    end

    it "returns 404 for a missing package" do
      sign_in admin
      get "/api/v1/wine_packages/999999"

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for a package the caller cannot see" do
      sign_in outsider
      get "/api/v1/wine_packages/#{package.id}"

      expect(response).to have_http_status(:not_found)
    end

    it "is visible to the user who recorded it even without being the reviewer" do
      recorder = user_with_role("Reviewer", "Package Recorder", "package-recorder@example.com")
      recorded = create_package(reviewer: nil, created_by: recorder)

      sign_in recorder
      get "/api/v1/wine_packages/#{recorded.id}"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "workflow actions" do
    before { sign_in admin }

    it "marks a package in transit from announced" do
      package = create_package(status: "announced")
      post "/api/v1/wine_packages/#{package.id}/mark_in_transit"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["status"]).to eq("in_transit")
    end

    it "rejects a transition the workflow forbids" do
      package = create_package
      post "/api/v1/wine_packages/#{package.id}/mark_in_transit"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("cannot transition")
      expect(package.reload.status).to eq("draft")
    end

    it "marks arrival, starting the one-month review clock" do
      package = create_package
      post "/api/v1/wine_packages/#{package.id}/mark_arrived"

      expect(response).to have_http_status(:ok)
      package.reload
      expect(package.status).to eq("arrived")
      expect(package.arrived_at.to_date).to eq(Date.current)
      expect(package.review_deadline).to eq(Date.current.>>(1))
      expect(Notification.where(wine_package: package).count).to eq(3)
    end

    it "preserves an explicit deadline supplied with arrival" do
      package = create_package
      deadline = Date.current + 5
      post "/api/v1/wine_packages/#{package.id}/mark_arrived",
           as: :json, params: { review_deadline: deadline.iso8601 }

      expect(response).to have_http_status(:ok)
      expect(package.reload.review_deadline).to eq(deadline)
    end
  end

  describe "workflow: completion, accept/reject, cancel" do
    before { sign_in admin }

    it "completes explicitly, reopens, and completes again" do
      package = create_package(status: "arrived", arrived_at: Time.current, review_deadline: Date.current + 10)

      post "/api/v1/wine_packages/#{package.id}/mark_completed"
      expect(response).to have_http_status(:ok)
      expect(package.reload.status).to eq("completed")
      expect(package.auto_completed).to be false

      post "/api/v1/wine_packages/#{package.id}/reopen"
      expect(response).to have_http_status(:ok)
      expect(package.reload.status).to eq("reviewing")

      post "/api/v1/wine_packages/#{package.id}/mark_completed"
      expect(package.reload.status).to eq("completed")
    end

    it "accepts a producer request" do
      package = create_package(status: "requested", requested_at: Time.current)
      post "/api/v1/wine_packages/#{package.id}/accept"

      expect(response).to have_http_status(:ok)
      package.reload
      expect(package.status).to eq("accepted")
      expect(package.accepted_by_id).to eq(admin.id)
      expect(package.accepted_at).to be_present
    end

    it "requires a reason to reject, then records the actor" do
      package = create_package(status: "requested", requested_at: Time.current)

      post "/api/v1/wine_packages/#{package.id}/reject"
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to be_present

      post "/api/v1/wine_packages/#{package.id}/reject",
           as: :json, params: { rejection_reason: "Not this season" }
      expect(response).to have_http_status(:ok)
      package.reload
      expect(package.status).to eq("rejected")
      expect(package.rejected_by_id).to eq(admin.id)
      expect(package.rejection_reason).to eq("Not this season")
    end

    it "cancels a package" do
      package = create_package(status: "announced")
      post "/api/v1/wine_packages/#{package.id}/cancel"

      expect(response).to have_http_status(:ok)
      expect(package.reload.status).to eq("cancelled")
    end

    it "does not allow jumping straight out of a cancelled or completed package" do
      cancelled = create_package(status: "cancelled")
      post "/api/v1/wine_packages/#{cancelled.id}/reopen"
      expect(response).to have_http_status(:unprocessable_entity)

      completed = create_package(status: "completed", arrived_at: Time.current,
                                 review_deadline: Date.current + 10)
      post "/api/v1/wine_packages/#{completed.id}/cancel"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "lets the responsible reviewer act, but not an unrelated user" do
      package = create_package(reviewer: reviewer_user, created_by: admin, status: "announced")

      sign_in reviewer_user
      post "/api/v1/wine_packages/#{package.id}/mark_in_transit"
      expect(response).to have_http_status(:ok)

      sign_in outsider
      post "/api/v1/wine_packages/#{package.id}/mark_arrived"
      expect(response).to have_http_status(:forbidden)
      expect(package.reload.status).to eq("in_transit")
    end

    it "audits workflow actions under a dedicated action name" do
      package = create_package
      post "/api/v1/wine_packages/#{package.id}/mark_arrived"

      expect(Log.where(action: "wine_package.arrived").count).to eq(1)
      expect(Log.where(action: "wine_package.arrived").first.description).to include("Mark arrived")
    end
  end

  describe "PATCH /api/v1/wine_packages/:id" do
    before { sign_in admin }

    it "updates editable attributes" do
      package = create_package
      patch "/api/v1/wine_packages/#{package.id}", as: :json, params: {
        wine_package: { notes: "Two bottles damaged", expected_at: (Date.current + 3).iso8601 }
      }

      expect(response).to have_http_status(:ok)
      package.reload
      expect(package.notes).to eq("Two bottles damaged")
      expect(package.expected_at).to eq(Date.current + 3)
    end

    it "ignores attempts to write the workflow-owned status and source" do
      package = create_package(status: "announced")
      patch "/api/v1/wine_packages/#{package.id}", as: :json, params: {
        wine_package: { status: "completed", source: "producer_request", notes: "keep me" }
      }

      expect(response).to have_http_status(:ok)
      package.reload
      expect(package.status).to eq("announced")
      expect(package.source).to eq("unexpected")
      expect(package.notes).to eq("keep me")
    end

    it "lets a manager hand the package to another reviewer" do
      package = create_package
      patch "/api/v1/wine_packages/#{package.id}", as: :json, params: {
        wine_package: { reviewer_id: reviewer_user.id }
      }

      expect(response).to have_http_status(:ok)
      expect(package.reload.reviewer_id).to eq(reviewer_user.id)
    end

    it "is forbidden for an unrelated user" do
      package = create_package
      sign_in outsider
      patch "/api/v1/wine_packages/#{package.id}", as: :json, params: {
        wine_package: { notes: "nope" }
      }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/wine_packages/:id" do
    before { sign_in admin }

    it "deletes the package and its dependent rows" do
      package = create_package(status: "arrived", arrived_at: Time.current,
                               review_deadline: Date.current + 10)
      package.wine_package_items.create!(quantity: 1, review_requested: true)

      delete "/api/v1/wine_packages/#{package.id}"

      expect(response).to have_http_status(:no_content)
      expect(WinePackage.exists?(package.id)).to be false
      expect(WinePackageItem.where(wine_package_id: package.id).count).to eq(0)
      expect(Notification.where(wine_package_id: package.id).count).to eq(0)
    end
  end
end
