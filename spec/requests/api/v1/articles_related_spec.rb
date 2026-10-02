require "rails_helper"
require "devise"

# Request specs for Api::V1::ArticlesController#related — the "more articles"
# footer on the article page. It serves the newest articles from the same
# categories, excluding the one being viewed, and deals the slots round-robin
# when the article belongs to several categories.
RSpec.describe "Api::V1::Articles related", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:author) do
    User.create!(user_name: "Author", email: "related-author@example.com", password: "password123")
  end
  let(:manager) do
    user = User.create!(user_name: "Manager", email: "related-manager@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end
  let(:burgundy) { Category.create!(name: "Burgundy") }
  let(:barossa) { Category.create!(name: "Barossa") }

  # `days_ago` keeps the expected "newest first" order explicit.
  def create_article(title, categories: [ burgundy ], status: "published", days_ago: 10)
    article = Article.create!(
      title: title,
      status: status,
      user: author,
      abstract: "#{title} abstract",
      published_at: status == "published" ? days_ago.days.ago : nil
    )
    article.update_column(:created_at, days_ago.days.ago)
    categories.each { |category| ArticleCategory.create!(article: article, category: category) }
    article
  end

  def related_ids
    JSON.parse(response.body).map { |a| a["id"] }
  end

  describe "GET /api/v1/articles/:id/related" do
    it "returns an empty list for an uncategorised article" do
      article = create_article("Uncategorised", categories: [])

      get "/api/v1/articles/#{article.slug}/related"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end

    it "returns the newest articles of the same category, excluding itself" do
      article = create_article("Current", days_ago: 1)
      newest = create_article("Newest", days_ago: 2)
      older = create_article("Older", days_ago: 5)

      get "/api/v1/articles/#{article.slug}/related"

      expect(response).to have_http_status(:ok)
      expect(related_ids).to eq([ newest.id, older.id ])
    end

    it "serializes the rows with the fields the footer card renders" do
      article = create_article("Current", days_ago: 1)
      other = create_article("Sibling", days_ago: 2)

      get "/api/v1/articles/#{article.slug}/related"

      row = JSON.parse(response.body).sole
      expect(row).to include(
        "id" => other.id,
        "slug" => other.slug,
        "title" => "Sibling",
        "abstract" => "Sibling abstract",
        "author_name" => "Author",
        "status" => "published",
        "likes_count" => 0,
        "liked_by_current_user" => false
      )
      expect(row["images"]).to eq([])
    end

    it "caps the list at the requested limit, newest first" do
      article = create_article("Current", days_ago: 1)
      siblings = 4.times.map { |i| create_article("Sibling #{i}", days_ago: 2 + i) }

      get "/api/v1/articles/#{article.slug}/related", params: { limit: 3 }

      expect(related_ids).to eq(siblings.first(3).map(&:id))
    end

    it "deals the slots across the categories instead of exhausting the first" do
      article = create_article("Current", categories: [ burgundy, barossa ], days_ago: 1)
      # Burgundy has three articles and Barossa one, so taking them in category
      # order would drop the Barossa one entirely.
      burgundy_a = create_article("Burgundy A", categories: [ burgundy ], days_ago: 2)
      burgundy_b = create_article("Burgundy B", categories: [ burgundy ], days_ago: 3)
      burgundy_c = create_article("Burgundy C", categories: [ burgundy ], days_ago: 4)
      barossa_a = create_article("Barossa A", categories: [ barossa ], days_ago: 5)

      get "/api/v1/articles/#{article.slug}/related", params: { limit: 4 }

      expect(related_ids).to contain_exactly(burgundy_a.id, burgundy_b.id, burgundy_c.id, barossa_a.id)
      # The Barossa article is not last: it shares the rows with Burgundy.
      expect(related_ids.index(barossa_a.id)).to be < related_ids.index(burgundy_c.id)
    end

    it "lists an article that belongs to two of the categories only once" do
      article = create_article("Current", categories: [ burgundy, barossa ], days_ago: 1)
      both = create_article("Both", categories: [ burgundy, barossa ], days_ago: 2)
      burgundy_only = create_article("Burgundy only", categories: [ burgundy ], days_ago: 3)

      get "/api/v1/articles/#{article.slug}/related"

      # "Both" is in the per-category list twice; it must survive the interleave
      # once, and the Burgundy-only sibling must still make the list.
      expect(related_ids).to contain_exactly(both.id, burgundy_only.id)
      expect(related_ids).to eq(related_ids.uniq)
    end

    it "hides other people's drafts from guests" do
      article = create_article("Current", days_ago: 1)
      published = create_article("Published sibling", days_ago: 2)
      draft = create_article("Someone else's draft", status: "draft", days_ago: 3)

      get "/api/v1/articles/#{article.slug}/related"

      expect(related_ids).to eq([ published.id ])
      expect(related_ids).not_to include(draft.id)
    end

    it "includes drafts once signed in as a content manager" do
      article = create_article("Current", days_ago: 1)
      draft = create_article("Manager's draft", status: "draft", days_ago: 2)
      sign_in manager

      get "/api/v1/articles/#{article.slug}/related"

      expect(related_ids).to include(draft.id)
    end
  end
end
