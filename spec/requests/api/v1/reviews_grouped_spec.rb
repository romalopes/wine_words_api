require "rails_helper"
require "devise"

# Request specs for Api::V1::ReviewsController#grouped — the "12 per category"
# listing the Reviews page renders when no category is selected. Because that
# view backs the no-category listing, it has to honour the same visibility and
# `query` search scoping as the paginated feed (#index).
RSpec.describe "Api::V1::Reviews grouped", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:producer) { Producer.create!(name: "Grouped Producer") }
  let(:wine) { Wine.create!(name: "Grouped Wine", producer: producer, color: "Red") }
  let(:vintage) { Vintage.create!(wine: wine, year: 2020) }
  let(:reviewer) do
    User.create!(first_name: "Reviewer", email: "reviewer@example.com", password: "password123")
  end
  let(:manager) do
    user = User.create!(first_name: "Manager", email: "review-manager@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end
  let(:category) { Category.create!(name: "Top Value") }

  def create_review(title, status: "published", user: reviewer)
    review = Review.create!(vintage: vintage, user: user, title: title, score: 90, status: status)
    ReviewCategory.create!(review: review, category: category)
    review
  end

  # Two published (one matching "malbec") plus a draft that also matches.
  before do
    create_review("A lovely malbec")
    create_review("A crisp riesling")
    create_review("Draft malbec", status: "draft")
  end

  describe "GET /api/v1/reviews/grouped" do
    it "groups published reviews by category" do
      get "/api/v1/reviews/grouped"

      expect(response).to have_http_status(:ok)
      group = JSON.parse(response.body).find { |g| g["category"] == "Top Value" }
      expect(group["reviews"].map { |r| r["title"] })
        .to contain_exactly("A lovely malbec", "A crisp riesling")
    end

    it "hides drafts from guests" do
      get "/api/v1/reviews/grouped"

      titles = JSON.parse(response.body).flat_map { |g| g["reviews"].map { |r| r["title"] } }
      expect(titles).not_to include("Draft malbec")
    end

    it "filters the grouped view by query (search with no category)" do
      get "/api/v1/reviews/grouped", params: { query: "malbec" }

      group = JSON.parse(response.body).find { |g| g["category"] == "Top Value" }
      expect(group["reviews"].map { |r| r["title"] }).to contain_exactly("A lovely malbec")
      expect(group["count"]).to eq(1)
    end

    it "matches the query against the wine name too" do
      get "/api/v1/reviews/grouped", params: { query: "Grouped Wine" }

      titles = JSON.parse(response.body).flat_map { |g| g["reviews"].map { |r| r["title"] } }
      expect(titles).to contain_exactly("A lovely malbec", "A crisp riesling")
    end

    it "returns no groups when the query matches nothing" do
      get "/api/v1/reviews/grouped", params: { query: "zzzz" }

      expect(JSON.parse(response.body)).to eq([])
    end

    it "caps each group at per_group but keeps the true count" do
      3.times { |i| create_review("Extra note #{i}") }

      get "/api/v1/reviews/grouped", params: { per_group: 2 }

      group = JSON.parse(response.body).find { |g| g["category"] == "Top Value" }
      expect(group["reviews"].length).to eq(2)
      expect(group["count"]).to eq(5)
    end

    it "supports the full-text search param" do
      get "/api/v1/reviews/grouped", params: { search: "malbec" }

      titles = JSON.parse(response.body).flat_map { |g| g["reviews"].map { |r| r["title"] } }
      expect(titles).to include("A lovely malbec")
    end

    context "when signed in as a content manager" do
      before { sign_in manager }

      it "includes drafts" do
        get "/api/v1/reviews/grouped"

        titles = JSON.parse(response.body).flat_map { |g| g["reviews"].map { |r| r["title"] } }
        expect(titles).to include("Draft malbec")
      end

      it "matches drafts by query too" do
        get "/api/v1/reviews/grouped", params: { query: "Draft" }

        titles = JSON.parse(response.body).flat_map { |g| g["reviews"].map { |r| r["title"] } }
        expect(titles).to contain_exactly("Draft malbec")
      end
    end
  end
end
