require "rails_helper"
require "devise"

# Request specs for Api::V1::CategoriesController#counts — the payload behind
# the React nav dropdown. The controller caches the whole payload for 60s
# (split by manager scope) because it costs ~8 count queries per page load.
RSpec.describe "Api::V1::Categories counts", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:reviewer) do
    User.create!(first_name: "Reviewer", email: "counts-reviewer@example.com", password: "password123")
  end
  let(:manager) do
    user = User.create!(first_name: "Manager", email: "counts-manager@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end
  let(:wine) { Wine.create!(name: "Counts Wine", producer: Producer.create!(name: "Counts Producer"), color: "Red") }
  let(:vintage) { Vintage.create!(wine: wine, year: 2020) }
  let(:wine_category) { Category.create!(name: "Counts Wine Cat", for_wine: true) }
  let(:review_category) { Category.create!(name: "Counts Review Cat", for_review: true) }
  let(:article_category) { Category.create!(name: "Counts Article Cat", for_article: true) }
  let(:article) { Article.create!(title: "Counts article", user: reviewer, status: "published", body: "b") }

  def create_review(title, status: "published")
    review = Review.create!(vintage: vintage, user: reviewer, title: title, score: 90, status: status)
    ReviewCategory.create!(review: review, category: review_category)
    review
  end

  before do
    WineCategory.create!(wine: wine, category: wine_category)
    create_review("Published counts review")
    create_review("Draft counts review", status: "draft")
    ArticleCategory.create!(article: article, category: article_category)
  end

  # The test env cache store is :null_store, which never caches. Swap in a
  # MemoryStore so the caching behaviour itself can be asserted.
  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
    Rails.cache = original_cache
  end

  describe "GET /api/v1/categories/counts" do
    it "counts only published items for a visitor" do
      get "/api/v1/categories/counts"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["review"][review_category.id.to_s]).to eq(1)
      expect(body["article"][article_category.id.to_s]).to eq(1)
      expect(body["totals"]["review"]).to eq(1)
      expect(body["totals"]["article"]).to eq(1)
    end

    it "counts drafts too for a manager" do
      sign_in manager
      get "/api/v1/categories/counts"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["review"][review_category.id.to_s]).to eq(2)
      expect(body["totals"]["review"]).to eq(2)
    end

    it "serves the second request from cache without issuing count queries" do
      get "/api/v1/categories/counts"
      expect(response).to have_http_status(:ok)
      first_body = response.body

      queries = []
      callback = ->(*args) { queries << args.last[:sql] }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get "/api/v1/categories/counts"
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(first_body)
      expect(queries.grep(/SELECT COUNT\(\*\)/i)).to be_empty
    end

    it "caches manager and public payloads separately" do
      get "/api/v1/categories/counts"
      public_body = JSON.parse(response.body)

      sign_in manager
      get "/api/v1/categories/counts"
      manager_body = JSON.parse(response.body)

      expect(manager_body["totals"]["review"]).to eq(2)
      expect(public_body["totals"]["review"]).to eq(1)
    end
  end
end
