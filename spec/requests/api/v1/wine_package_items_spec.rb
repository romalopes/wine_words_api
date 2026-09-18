require "rails_helper"

# Request specs for Api::V1::WinePackageItemsController — the wine lines inside
# a package and the point where a review is started from the workflow.
RSpec.describe "Api::V1::WinePackageItems", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:producer) { Producer.create!(name: "Penfolds") }
  let(:admin) do
    user = User.create!(user_name: "Items Admin", email: "items-admin@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end
  let(:outsider) { User.create!(user_name: "Items Outsider", email: "items-outsider@example.com", password: "password123") }
  let(:wine) { Wine.create!(name: "Bin 389", color: "Red", producer: producer) }
  let(:vintage) { Vintage.create!(wine: wine, year: 2020) }

  let(:package) do
    WinePackage.create!(producer: producer, reviewer: admin, created_by: admin,
                        source: "unexpected", status: "arrived",
                        arrived_at: Time.current, review_deadline: Date.current + 30)
  end

  before { sign_in admin }

  describe "POST /api/v1/wine_packages/:wine_package_id/items" do
    it "adds a review-requested line and keeps the package incomplete" do
      post "/api/v1/wine_packages/#{package.id}/items", as: :json, params: {
        item: { vintage_id: vintage.id, quantity: 2, review_requested: true,
                condition: "sealed" }
      }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to include(
        "vintage_id" => vintage.id,
        "wine_name" => "Bin 389",
        "vintage_year" => 2020,
        "label" => "Bin 389 2020",
        "quantity" => 2,
        "review_requested" => true,
        "reviewed" => false,
        "pending_review" => true
      )
      expect(package.reload.pending_review_count).to eq(1)
      expect(package.status).to eq("arrived")
    end

    it "allows a line whose wine is not in the catalogue yet" do
      post "/api/v1/wine_packages/#{package.id}/items", as: :json, params: {
        item: { quantity: 1, review_requested: false }
      }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["label"]).to eq("Unmatched wine")
    end

    it "rejects a non-positive quantity" do
      post "/api/v1/wine_packages/#{package.id}/items", as: :json, params: {
        item: { vintage_id: vintage.id, quantity: 0 }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to be_present
    end

    it "returns 404 for an unknown package" do
      post "/api/v1/wine_packages/999999/items", as: :json, params: { item: { quantity: 1 } }
      expect(response).to have_http_status(:not_found)
    end

    it "is forbidden for an unrelated user" do
      sign_in outsider
      post "/api/v1/wine_packages/#{package.id}/items", as: :json, params: {
        item: { vintage_id: vintage.id, quantity: 1 }
      }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/wine_packages/:wine_package_id/items/:id" do
    let!(:item) { package.wine_package_items.create!(vintage: vintage, review_requested: true) }

    it "updates the line's condition and notes" do
      patch "/api/v1/wine_packages/#{package.id}/items/#{item.id}", as: :json, params: {
        item: { condition: "damaged label", notes: "One bottle" }
      }

      expect(response).to have_http_status(:ok)
      item.reload
      expect(item.condition).to eq("damaged label")
      expect(item.notes).to eq("One bottle")
    end

    it "completes the package when the last *remaining* blocking line stops requiring a review" do
      # This line is fulfilled by a published review, so the package would
      # auto-complete — until a second requested line arrives, which must
      # reopen it.
      published = Review.create!(vintage: vintage, user: admin, title: "Fulfilled",
                                score: 90, status: "published")
      item.update!(review: published)
      expect(package.reload.status).to eq("completed")

      blocking = package.wine_package_items.create!(vintage: vintage, review_requested: true)
      expect(package.reload.status).to eq("reviewing")

      patch "/api/v1/wine_packages/#{package.id}/items/#{blocking.id}", as: :json, params: {
        item: { review_requested: false }
      }

      expect(response).to have_http_status(:ok)
      package.reload
      expect(package.status).to eq("completed")
      expect(package.auto_completed).to be true
      expect(package.pending_review_count).to eq(0)
    end

    it "leaves the package open when the ONLY requested line is un-requested" do
      # Documented guard: auto-completion requires at least one requested line,
      # so a package that never (or no longer) asks for a review is finished
      # deliberately with mark_completed, not silently.
      patch "/api/v1/wine_packages/#{package.id}/items/#{item.id}", as: :json, params: {
        item: { review_requested: false }
      }

      expect(response).to have_http_status(:ok)
      package.reload
      expect(package.status).to eq("arrived")
      expect(package.can_transition_to?("completed")).to be true
    end
  end

  describe "DELETE /api/v1/wine_packages/:wine_package_id/items/:id" do
    it "removes the line and completes the package when nothing is left pending" do
      fulfilled = package.wine_package_items.create!(vintage: vintage, review_requested: true)
      published = Review.create!(vintage: vintage, user: admin, title: "Fulfilled delete",
                                score: 90, status: "published")
      fulfilled.update!(review: published)
      removable = package.wine_package_items.create!(vintage: vintage, review_requested: true)

      delete "/api/v1/wine_packages/#{package.id}/items/#{removable.id}"

      expect(response).to have_http_status(:no_content)
      expect(WinePackageItem.exists?(removable.id)).to be false
      expect(package.reload.status).to eq("completed")
      expect(package.auto_completed).to be true
    end
  end

  describe "POST /api/v1/wine_packages/:wine_package_id/items/:id/create_review" do
    let!(:item) { package.wine_package_items.create!(vintage: vintage, review_requested: true) }

    it "creates a review through the ordinary review path and links it" do
      post "/api/v1/wine_packages/#{package.id}/items/#{item.id}/create_review", as: :json, params: {
        review: { title: "Bin 389 2020", score: 92, status: "published" }
      }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to include("title" => "Bin 389 2020", "status" => "published", "vintage_id" => vintage.id)

      review = Review.find(body["id"])
      expect(review.user_id).to eq(admin.id)
      expect(item.reload.review_id).to eq(review.id)

      # A published review releases the line, so the package completes.
      package.reload
      expect(package.status).to eq("completed")
      expect(package.auto_completed).to be true
      expect(package.review_progress).to eq(requested: 1, reviewed: 1, pending: 0, percent: 100)
    end

    it "creates a draft review without completing the package" do
      post "/api/v1/wine_packages/#{package.id}/items/#{item.id}/create_review", as: :json, params: {
        review: { title: "Draft review", score: 90 }
      }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["status"]).to eq("draft")
      expect(package.reload.status).to eq("arrived")
      expect(package.pending_review_count).to eq(1)
    end

    it "refuses a line that was not requested for review" do
      other = package.wine_package_items.create!(vintage: vintage, review_requested: false)

      post "/api/v1/wine_packages/#{package.id}/items/#{other.id}/create_review", as: :json, params: {
        review: { title: "Should not exist", score: 80 }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("not marked for review")
    end

    it "refuses a line with no wine in the catalogue" do
      unmatched = package.wine_package_items.create!(review_requested: true)

      post "/api/v1/wine_packages/#{package.id}/items/#{unmatched.id}/create_review", as: :json, params: {
        review: { title: "Should not exist", score: 80 }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("not linked to a wine")
    end

    it "refuses a line that already has a review" do
      post "/api/v1/wine_packages/#{package.id}/items/#{item.id}/create_review", as: :json, params: {
        review: { title: "First", score: 90, status: "published" }
      }
      expect(response).to have_http_status(:created)

      post "/api/v1/wine_packages/#{package.id}/items/#{item.id}/create_review", as: :json, params: {
        review: { title: "Second", score: 91 }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("already has a review")
    end

    it "audits the created review" do
      post "/api/v1/wine_packages/#{package.id}/items/#{item.id}/create_review", as: :json, params: {
        review: { title: "Audited", score: 90 }
      }

      expect(Log.where(action: "wine_package_item.review_created").count).to eq(1)
    end
  end
end
