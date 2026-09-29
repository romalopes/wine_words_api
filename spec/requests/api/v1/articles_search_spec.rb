require "rails_helper"
require "devise"

# Search and sorting for Api::V1::ArticlesController#index / #grouped — what the
# All Articles page sends: one `query` term (full-text, not a title LIKE) plus a
# `sort` value from the dropdown. Both endpoints must agree, because the page
# shows the grouped view until a category is picked.
RSpec.describe "Api::V1::Articles search and sort", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:author) do
    User.create!(user_name: "Scribe", email: "scribe@example.com", password: "password123")
  end
  let(:category) { Category.create!(name: "Regions") }

  def create_article(title, body: nil, tag_names: [], status: "published", created_at: nil)
    article = Article.create!(title: title, body: body, status: status, user: author)
    if tag_names.any?
      tag_names.each do |name|
        ArticleTag.create!(article: article, tag: Tag.find_or_create_by_name(name))
      end
      article.save! # the vector is built on save, before join rows exist
    end
    article.update_columns(created_at: created_at) if created_at
    ArticleCategory.create!(article: article, category: category)
    article.reload
  end

  def index_titles(params = {})
    get "/api/v1/articles", params: params
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body).map { |a| a["title"] }
  end

  def grouped_titles(params = {})
    get "/api/v1/articles/grouped", params: params
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body).flat_map { |g| g["articles"].map { |a| a["title"] } }
  end

  describe "GET /api/v1/articles" do
    it "searches the whole weighted vector, not just the title" do
      create_article("Regional overview", body: "Shiraz dominates the plantings here.")
      create_article("Harvest diary", tag_names: ["vineyard"])
      create_article("Unrelated note")

      expect(index_titles(query: "shiraz")).to eq(["Regional overview"])
      expect(index_titles(query: "vineyard")).to eq(["Harvest diary"])
    end

    it "requires every word of a multi-word term, in any field" do
      create_article("Barossa gems", body: "The best shiraz vintages live here.")
      create_article("Barossa only", body: "No grape variety named here.")

      expect(index_titles(query: "barossa shiraz")).to eq(["Barossa gems"])
    end

    it "matches prefixes so a partial word still finds the whole one" do
      create_article("Chardonnay, chilled")
      create_article("Pinot Noir, cellared")

      expect(index_titles(query: "char")).to eq(["Chardonnay, chilled"])
    end

    it "orders by relevance, putting the title hit above the body hit" do
      create_article("Regional overview", body: "Shiraz dominates the plantings here.")
      create_article("Shiraz showcase", body: "A region overview.")

      expect(index_titles(query: "shiraz")).to eq(["Shiraz showcase", "Regional overview"])
    end

    it "accepts the deprecated `search` spelling of the term" do
      create_article("Shiraz showcase")

      expect(index_titles(search: "shiraz")).to eq(["Shiraz showcase"])
    end

    it "answers 200 with an unfiltered list for input that cannot be searched" do
      create_article("Shiraz showcase")

      # Operators used to reach to_tsquery untouched, which raised and 500ed.
      expect(index_titles(query: " & : ' !")).to eq(["Shiraz showcase"])
      expect(index_titles(query: "a")).to eq(["Shiraz showcase"])
    end

    it "counts matches correctly while paginating a search" do
      3.times { |i| create_article("Shiraz note #{i}") }
      create_article("Unrelated note")

      get "/api/v1/articles", params: { query: "shiraz", page: 1, per_page: 2 }
      body = JSON.parse(response.body)

      expect(body["total_count"]).to eq(3)
      expect(body["total_pages"]).to eq(2)
      expect(body["items"].length).to eq(2)
    end

    it "ignores the relevance ordering when the newest article is the older hit" do
      oldest = create_article("Shiraz showcase", created_at: 3.days.ago)
      create_article("Regional overview", body: "Shiraz dominates here.", created_at: 1.day.ago)

      titles = index_titles(query: "shiraz", sort: "recent")
      expect(titles).to eq(["Regional overview", oldest.title])
      expect(index_titles(query: "shiraz", sort: "oldest")).to eq(titles.reverse)
    end

    it "falls back to recency for a sort that articles do not offer" do
      create_article("Old note", created_at: 2.days.ago)
      create_article("New note", created_at: 1.hour.ago)

      expect(index_titles(sort: "score_high")).to eq(["New note", "Old note"])
    end
  end

  describe "GET /api/v1/articles/grouped" do
    before do
      create_article("Barossa gems", body: "The best shiraz vintages live here.", created_at: 2.days.ago)
      create_article("Shiraz showcase", created_at: 1.day.ago)
      create_article("Mosel roundup", created_at: 3.days.ago)
    end

    it "agrees with the feed about what matches" do
      expect(grouped_titles(query: "shiraz")).to match_array(index_titles(query: "shiraz"))
      expect(grouped_titles(query: "barossa shiraz")).to eq(["Barossa gems"])
    end

    it "orders each category by relevance" do
      expect(grouped_titles(query: "shiraz")).to eq(["Shiraz showcase", "Barossa gems"])
    end

    it "honours the sort param inside each category" do
      expect(grouped_titles(query: "shiraz", sort: "oldest"))
        .to eq(["Barossa gems", "Shiraz showcase"])
    end

    it "keeps drafts invisible while searching" do
      create_article("Shiraz draft", status: "draft")

      expect(grouped_titles(query: "shiraz")).to eq(["Shiraz showcase", "Barossa gems"])
      expect(index_titles(query: "shiraz")).to eq(["Shiraz showcase", "Barossa gems"])
    end

    it "answers 200 and skips filtering for input that cannot be searched" do
      expect(grouped_titles(query: "<> & !")).to eq(index_titles(sort: "recent"))
    end
  end
end
