require "rails_helper"

# Request specs for Api::V1::FollowsController — the signed-in user's
# subscriptions to Producers / Wines / Reviews / Articles (issue #192).
# One Follow row per user/target; drafts are 404 for users who cannot see
# them, mirroring the likes/comments visibility rules.
RSpec.describe "Api::V1::Follows", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { User.create!(first_name: "Follow Req", email: "follow-req@example.com", password: "password123") }
  let(:other_user) { User.create!(first_name: "Follow Other", email: "follow-other@example.com", password: "password123") }
  let(:manager) { User.create!(first_name: "Follow Mgr", email: "follow-mgr@example.com", password: "password123").tap { |u| u.roles << Role.find_or_create_by!(name: "Reviewer") } }
  let(:producer) { Producer.create!(name: "Follow Req Producer") }
  let(:wine) { Wine.create!(name: "Follow Req Wine", producer: producer, color: "Red", closure: "Cork", alcohol_percentage: 13.5, volume_ml: 750) }
  let(:vintage) { Vintage.create!(wine: wine, year: 2020) }
  let(:review) { Review.create!(vintage: vintage, user: other_user, title: "Follow Req Review", comment: "Note", score: 90, status: "published", source: "manual") }
  let(:draft_review) { Review.create!(vintage: vintage, user: other_user, title: "Follow Req Draft", comment: "Note", score: 80, status: "draft", source: "manual") }
  let(:article) { Article.create!(user: other_user, title: "Follow Req Article", abstract: "Abstract", body: "Body", status: "published", source: "manual") }

  before { sign_in user }

  describe "POST /api/v1/follows" do
    it "creates a follow for a producer" do
      post "/api/v1/follows", params: { followable_type: "Producer", followable_id: producer.id }, as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["followable_type"]).to eq("Producer")
      expect(body["followable_id"]).to eq(producer.id)
      expect(body["target_label"]).to eq("Follow Req Producer")
      expect(body["target_path"]).to eq("/producers/#{producer.slug}")
      expect(body["following"]).to be true
    end

    it "resolves a wine by slug" do
      post "/api/v1/follows", params: { followable_type: "Wine", followable_slug: wine.slug }, as: :json

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["followable_id"]).to eq(wine.id)
    end

    it "is idempotent: a repeated POST returns the same row" do
      post "/api/v1/follows", params: { followable_type: "Wine", followable_id: wine.id }, as: :json
      expect(response).to have_http_status(:created)

      post "/api/v1/follows", params: { followable_type: "Wine", followable_id: wine.id }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["id"]).to eq(Follow.last.id)
      expect(Follow.where(user: user, followable: wine).count).to eq(1)
    end

    it "rejects an unknown followable type" do
      post "/api/v1/follows", params: { followable_type: "Vintage", followable_id: vintage.id }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(Follow.count).to eq(0)
    end

    it "returns 404 for a missing target" do
      post "/api/v1/follows", params: { followable_type: "Wine", followable_id: 999_999 }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "hides another user's draft review behind a 404" do
      post "/api/v1/follows", params: { followable_type: "Review", followable_id: draft_review.id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(Follow.count).to eq(0)
    end

    it "lets a wine manager follow a draft review" do
      sign_in manager
      post "/api/v1/follows", params: { followable_type: "Review", followable_id: draft_review.id }, as: :json

      expect(response).to have_http_status(:created)
    end

    it "never accepts a user_id from the client" do
      post "/api/v1/follows", params: { followable_type: "Producer", followable_id: producer.id, user_id: other_user.id }, as: :json

      expect(response).to have_http_status(:created)
      expect(Follow.last.user_id).to eq(user.id)
    end

    it "requires authentication" do
      sign_out user
      post "/api/v1/follows", params: { followable_type: "Producer", followable_id: producer.id }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/follows" do
    before do
      Follow.create!(user: user, followable: producer)
      Follow.create!(user: user, followable: wine)
      Follow.create!(user: other_user, followable: review)
    end

    it "returns only the signed-in user's follows, newest first" do
      get "/api/v1/follows"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(2)
      expect(body.first["followable_type"]).to eq("Wine")
    end

    it "filters by type" do
      get "/api/v1/follows", params: { type: "Producer" }

      body = JSON.parse(response.body)
      expect(body.length).to eq(1)
      expect(body.first["followable_type"]).to eq("Producer")
    end

    it "paginates" do
      get "/api/v1/follows", params: { page: 1, per_page: 1 }

      body = JSON.parse(response.body)
      expect(body["total_count"]).to eq(2)
      expect(body["items"].length).to eq(1)
    end

    it "requires authentication" do
      sign_out user
      get "/api/v1/follows"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/follows/:id" do
    it "destroys the current user's follow" do
      follow = Follow.create!(user: user, followable: producer)

      delete "/api/v1/follows/#{follow.id}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["following"]).to be false
      expect(Follow.exists?(follow.id)).to be false
    end

    it "returns 404 for another user's follow" do
      follow = Follow.create!(user: other_user, followable: review)

      delete "/api/v1/follows/#{follow.id}"

      expect(response).to have_http_status(:not_found)
      expect(Follow.exists?(follow.id)).to be true
    end
  end

  describe "GET /api/v1/follows/status" do
    it "reports following: true when the user follows the target" do
      Follow.create!(user: user, followable: wine)

      get "/api/v1/follows/status", params: { followable_type: "Wine", followable_id: wine.id }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["following"]).to be true
      expect(body["follow_id"]).to be_present
    end

    it "reports following: true when the target is resolved by slug" do
      Follow.create!(user: user, followable: wine)

      get "/api/v1/follows/status", params: { followable_type: "Wine", followable_slug: wine.slug }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["following"]).to be true
      expect(body["followable_id"]).to eq(wine.id)
      expect(body["follow_id"]).to be_present
    end

    it "reports following: false when not following" do
      get "/api/v1/follows/status", params: { followable_type: "Wine", followable_id: wine.id }

      expect(JSON.parse(response.body)["following"]).to be false
    end

    it "returns 404 for a target the user cannot see" do
      get "/api/v1/follows/status", params: { followable_type: "Review", followable_id: draft_review.id }

      expect(response).to have_http_status(:not_found)
    end

    it "rejects an invalid type" do
      get "/api/v1/follows/status", params: { followable_type: "Vintage", followable_id: vintage.id }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "GET /api/v1/follows/statuses" do
    let(:wine2) { Wine.create!(name: "Follow Req Wine 2", producer: producer, color: "White", closure: "Cork", alcohol_percentage: 12.5, volume_ml: 750) }

    it "batch-reports which ids the user follows" do
      Follow.create!(user: user, followable: wine)

      get "/api/v1/follows/statuses", params: { followable_type: "Wine", ids: [wine.id, wine2.id] }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["followed_ids"]).to contain_exactly(wine.id)
    end

    it "rejects an invalid type" do
      get "/api/v1/follows/statuses", params: { followable_type: "Vintage", ids: [vintage.id] }

      expect(response).to have_http_status(:bad_request)
    end
  end
end