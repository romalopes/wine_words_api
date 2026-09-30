require "rails_helper"

RSpec.describe "Api::V1::Likes", type: :request do
  include Devise::Test::IntegrationHelpers

  def create_user(suffix)
    User.create!(user_name: "API Like #{suffix} #{SecureRandom.hex(2)}",
                 email: "api-like-#{suffix}-#{SecureRandom.hex(4)}@example.com",
                 password: "password123")
  end

  let(:user) { create_user("owner") }
  let(:other) { create_user("other") }
  let(:producer) { Producer.create!(name: "API Like Producer #{SecureRandom.hex(3)}") }
  let(:wine) { Wine.create!(name: "API Like Wine #{SecureRandom.hex(3)}", color: "Red", producer: producer) }
  let(:vintage) { Vintage.create!(wine: wine, year: 2020) }
  let(:review) do
    Review.create!(vintage: vintage, user: user, title: "API Like Review #{SecureRandom.hex(3)}",
                   score: 88, status: "published")
  end
  let(:article) { Article.create!(title: "API Like Article #{SecureRandom.hex(3)}", user: user, status: "published") }

  shared_examples "a likeable endpoint" do |path_for, record_name|
    let(:record) { send(record_name) }
    let(:path) { path_for.call(record) }

    it "rejects unauthenticated POST and DELETE" do
      post path
      expect(response).to have_http_status(:unauthorized)
      delete path
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates a like and returns liked=true with the count" do
      sign_in user
      post path
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to eq({ "liked" => true, "likes_count" => 1 })
      expect(record.reload.likes_count).to eq(1)
    end

    it "is idempotent on duplicate POST" do
      sign_in user
      post path
      post path
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({ "liked" => true, "likes_count" => 1 })
      expect(Like.where(user: user, likeable: record).count).to eq(1)
    end

    it "removes the like and is idempotent when no like exists" do
      sign_in user
      post path
      delete path
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({ "liked" => false, "likes_count" => 0 })

      delete path
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({ "liked" => false, "likes_count" => 0 })
    end

    it "returns 404 for a missing resource" do
      sign_in user
      post "#{path}-missing-999999"
      expect(response).to have_http_status(:not_found)
    end

    it "never allows liking on behalf of another user" do
      sign_in user
      post path, params: { user_id: other.id }
      expect(response).to have_http_status(:ok)
      expect(Like.where(likeable: record).pluck(:user_id)).to eq([ user.id ])
    end
  end

  describe "wines" do
    include_examples "a likeable endpoint",
                     ->(wine) { "/api/v1/wines/#{wine.slug}/like" }, :wine
  end

  describe "reviews" do
    include_examples "a likeable endpoint",
                     ->(review) { "/api/v1/reviews/#{review.slug}/like" }, :review
  end

  describe "articles" do
    include_examples "a likeable endpoint",
                     ->(article) { "/api/v1/articles/#{article.slug}/like" }, :article
  end

  it "returns 404 when liking a draft review the user cannot see" do
    draft = Review.create!(vintage: vintage, user: other, title: "Draft #{SecureRandom.hex(3)}",
                           score: 80, status: "draft")
    sign_in user
    post "/api/v1/reviews/#{draft.slug}/like"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when liking a draft article the user cannot see" do
    draft = Article.create!(title: "Draft #{SecureRandom.hex(3)}", user: other, status: "draft")
    sign_in user
    post "/api/v1/articles/#{draft.slug}/like"
    expect(response).to have_http_status(:not_found)
  end

  it "exposes likes_count and liked_by_current_user on show endpoints" do
    sign_in user
    post "/api/v1/wines/#{wine.slug}/like"

    get "/api/v1/wines/#{wine.slug}"
    body = JSON.parse(response.body)
    expect(body["likes_count"]).to eq(1)
    expect(body["liked_by_current_user"]).to be(true)

    sign_out user
    get "/api/v1/wines/#{wine.slug}"
    body = JSON.parse(response.body)
    expect(body["likes_count"]).to eq(1)
    expect(body["liked_by_current_user"]).to be(false)
  end
end
