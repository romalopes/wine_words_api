require "rails_helper"
require "devise"

# Request specs for the review entries embedded in
# Api::V1::ArticlesController#show. The article page renders each linked review
# with the shared review card, which needs the same fields `ReviewSerializer`
# ships (wine/vintage context, images and like state) — not just the stub the
# article page used to draw from.
RSpec.describe "Api::V1::Articles show reviews", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:author) do
    User.create!(user_name: "Author", email: "author-show@example.com", password: "password123")
  end
  let(:reviewer) do
    User.create!(user_name: "Reviewer", email: "reviewer-show@example.com", password: "password123")
  end
  let(:producer) { Producer.create!(name: "Show Producer") }
  let(:wine) { Wine.create!(name: "Barolo", producer: producer, color: "Red") }
  let(:vintage) { Vintage.create!(wine: wine, year: 2017) }
  let(:article) { Article.create!(title: "Barolo vertical", status: "published", user: author) }
  let(:review) do
    Review.create!(
      vintage: vintage,
      user: reviewer,
      title: "Yangarra Grenache",
      comment: "<p>Seeded review.</p>",
      score: 97,
      status: "published",
      drink_from: 2020,
      drink_to: 2028
    )
  end

  def link_article_review(link_status: "published")
    link = ArticleReview.create!(article: article, review: review)
    # `ArticleReview` forces new links to "published"; a draft link is reached by
    # demoting an existing one (or by unpublishing the review itself).
    link.update!(status: link_status) if link_status != "published"
    link
  end

  describe "GET /api/v1/articles/:slug" do
    it "returns the wine, vintage and drink window of each linked review" do
      link_article_review

      get "/api/v1/articles/#{article.slug}"

      expect(response).to have_http_status(:ok)
      entry = JSON.parse(response.body)["reviews"].sole
      expect(entry).to include(
        "id" => review.id,
        "slug" => review.slug,
        "title" => "Yangarra Grenache",
        "score" => 97.0,
        "status" => "published",
        "comment" => "<p>Seeded review.</p>",
        "reviewer_name" => "Reviewer",
        "link_status" => "published",
        "wine_name" => "Barolo",
        "wine_slug" => wine.slug,
        "vintage_id" => vintage.id,
        "vintage_year" => 2017,
        "drink_from" => 2020,
        "drink_to" => 2028
      )
    end

    it "includes the like fields and image list the review card renders" do
      link_article_review
      Like.create!(user: reviewer, likeable: review)

      get "/api/v1/articles/#{article.slug}"

      entry = JSON.parse(response.body)["reviews"].sole
      expect(entry["likes_count"]).to eq(1)
      expect(entry["liked_by_current_user"]).to eq(false) # guest
      expect(entry).to include("images" => [], "primary_image" => nil)
    end

    it "flags the review as liked for the user who liked it" do
      link_article_review
      Like.create!(user: reviewer, likeable: review)
      sign_in reviewer

      get "/api/v1/articles/#{article.slug}"

      expect(JSON.parse(response.body)["reviews"].sole["liked_by_current_user"]).to eq(true)
    end

    it "carries the per-link status so the page can hide unpublished links" do
      link_article_review(link_status: "draft")

      get "/api/v1/articles/#{article.slug}"

      expect(JSON.parse(response.body)["reviews"].sole["link_status"]).to eq("draft")
    end
  end
end
