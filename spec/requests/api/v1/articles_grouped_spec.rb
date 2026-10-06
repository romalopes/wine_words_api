require "rails_helper"
require "devise"

# Request specs for Api::V1::ArticlesController#grouped — the "12 per category"
# listing the Articles page renders when no category is selected. Because that
# view backs the no-category listing, it has to honour the same visibility and
# `query` search scoping as the paginated feed (#index).
RSpec.describe "Api::V1::Articles grouped", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:author) do
    User.create!(first_name: "Author", email: "author@example.com", password: "password123")
  end
  let(:manager) do
    user = User.create!(first_name: "Manager", email: "manager@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end
  let(:category) { Category.create!(name: "Tasting notes") }

  def create_article(title, status: "published", user: author)
    article = Article.create!(title: title, status: status, user: user)
    ArticleCategory.create!(article: article, category: category)
    article
  end

  # Two published (one matching "barolo") plus a draft that also matches.
  before do
    create_article("Barolo vertical")
    create_article("Rioja round-up")
    create_article("Barolo barrel sample", status: "draft")
  end

  describe "GET /api/v1/articles/grouped" do
    it "groups published articles by category" do
      get "/api/v1/articles/grouped"

      expect(response).to have_http_status(:ok)
      group = JSON.parse(response.body).find { |g| g["category"] == "Tasting notes" }
      expect(group["articles"].map { |a| a["title"] })
        .to contain_exactly("Barolo vertical", "Rioja round-up")
    end

    it "hides drafts from guests" do
      get "/api/v1/articles/grouped"

      titles = JSON.parse(response.body).flat_map { |g| g["articles"].map { |a| a["title"] } }
      expect(titles).not_to include("Barolo barrel sample")
    end

    it "filters the grouped view by query (search with no category)" do
      get "/api/v1/articles/grouped", params: { query: "barolo" }

      group = JSON.parse(response.body).find { |g| g["category"] == "Tasting notes" }
      expect(group["articles"].map { |a| a["title"] }).to contain_exactly("Barolo vertical")
      expect(group["count"]).to eq(1)
    end

    it "returns no groups when the query matches nothing" do
      get "/api/v1/articles/grouped", params: { query: "zzzz" }

      expect(JSON.parse(response.body)).to eq([])
    end

    it "caps each group at per_group but keeps the true count" do
      3.times { |i| create_article("Extra note #{i}") }

      get "/api/v1/articles/grouped", params: { per_group: 2 }

      group = JSON.parse(response.body).find { |g| g["category"] == "Tasting notes" }
      expect(group["articles"].length).to eq(2)
      expect(group["count"]).to eq(5)
    end

    it "supports the full-text search param" do
      get "/api/v1/articles/grouped", params: { search: "barolo" }

      titles = JSON.parse(response.body).flat_map { |g| g["articles"].map { |a| a["title"] } }
      expect(titles).to include("Barolo vertical")
    end

    context "when signed in as a content manager" do
      before { sign_in manager }

      it "includes drafts" do
        get "/api/v1/articles/grouped"

        titles = JSON.parse(response.body).flat_map { |g| g["articles"].map { |a| a["title"] } }
        expect(titles).to include("Barolo barrel sample")
      end

      it "matches drafts by query too" do
        get "/api/v1/articles/grouped", params: { query: "barrel" }

        titles = JSON.parse(response.body).flat_map { |g| g["articles"].map { |a| a["title"] } }
        expect(titles).to contain_exactly("Barolo barrel sample")
      end
    end
  end
end
