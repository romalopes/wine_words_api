require "rails_helper"
require "devise"

# Request specs for Api::V1::ReviewsController#related — the "more reviews"
# footer on the review page. Same contract as the article footer (see
# Api::RelatedFeed): newest reviews sharing this one's categories, excluding the
# one being viewed, slots dealt round-robin across categories.
RSpec.describe "Api::V1::Reviews related", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:author) do
    User.create!(first_name: "Author", email: "related-review-author@example.com", password: "password123")
  end
  let(:manager) do
    user = User.create!(first_name: "Manager", email: "related-review-manager@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end
  let(:producer) { Producer.create!(name: "Related Producer") }
  let(:wine) { Wine.create!(name: "Related Wine", producer: producer, color: "Red") }
  let(:vintage) { Vintage.create!(wine: wine, year: 2020) }
  let(:burgundy) { Category.create!(name: "Related Burgundy") }
  let(:barossa) { Category.create!(name: "Related Barossa") }

  # `days_ago` keeps the expected "newest first" order explicit.
  def create_review(title, categories: [ burgundy ], status: "published", days_ago: 10)
    review = Review.create!(
      vintage: vintage,
      user: author,
      title: title,
      comment: "<p>#{title} tasting note.</p>",
      score: 90,
      status: status,
      published_at: status == "published" ? days_ago.days.ago : nil
    )
    review.update_column(:created_at, days_ago.days.ago)
    categories.each { |category| ReviewCategory.create!(review: review, category: category) }
    review
  end

  def related_ids
    JSON.parse(response.body).map { |r| r["id"] }
  end

  describe "GET /api/v1/reviews/:id/related" do
    # The reported case: /reviews/chardonay-2026 is a review with no categories
    # at all, which used to render no footer.
    it "falls back to the newest reviews overall when the review has no categories" do
      review = create_review("Uncategorised", categories: [], days_ago: 1)
      # One categorised and one uncategorised sibling: with no categories to
      # intersect on, both are eligible and recency decides the order.
      newest = create_review("Categorised sibling", days_ago: 2)
      uncategorised = create_review("Uncategorised sibling", categories: [], days_ago: 3)

      get "/api/v1/reviews/#{review.slug}/related"

      expect(response).to have_http_status(:ok)
      expect(related_ids).to eq([ newest.id, uncategorised.id ])
      expect(related_ids).not_to include(review.id)
    end

    it "still hides other people's drafts from guests when falling back" do
      review = create_review("Uncategorised", categories: [], days_ago: 1)
      published = create_review("Published sibling", days_ago: 2)
      draft = create_review("Someone else's draft", status: "draft", days_ago: 3)

      get "/api/v1/reviews/#{review.slug}/related"

      expect(related_ids).to eq([ published.id ])
      expect(related_ids).not_to include(draft.id)
    end

    it "caps the uncategorised fallback at the requested limit" do
      review = create_review("Uncategorised", categories: [], days_ago: 1)
      siblings = 4.times.map { |i| create_review("Sibling #{i}", days_ago: 2 + i) }

      get "/api/v1/reviews/#{review.slug}/related", params: { limit: 3 }

      expect(related_ids).to eq(siblings.first(3).map(&:id))
    end

    it "returns the newest reviews of the same category, excluding itself" do
      review = create_review("Current", days_ago: 1)
      newest = create_review("Newest", days_ago: 2)
      older = create_review("Older", days_ago: 5)

      get "/api/v1/reviews/#{review.slug}/related"

      expect(response).to have_http_status(:ok)
      expect(related_ids).to eq([ newest.id, older.id ])
    end

    it "serializes the rows with the fields the footer card renders" do
      review = create_review("Current", days_ago: 1)
      other = create_review("Sibling", days_ago: 2)

      get "/api/v1/reviews/#{review.slug}/related"

      row = JSON.parse(response.body).sole
      expect(row).to include(
        "id" => other.id,
        "slug" => other.slug,
        "title" => "Sibling",
        # The preview line comes from the tasting note, which only the full
        # serializer ships.
        "comment" => "<p>Sibling tasting note.</p>",
        "reviewer_name" => "Author",
        "status" => "published",
        "wine_name" => "Related Wine",
        "vintage_year" => 2020,
        "likes_count" => 0,
        "liked_by_current_user" => false
      )
      expect(row["images"]).to eq([])
    end
    it "caps the list at the requested limit, newest first" do
      review = create_review("Current", days_ago: 1)
      siblings = 4.times.map { |i| create_review("Sibling #{i}", days_ago: 2 + i) }

      get "/api/v1/reviews/#{review.slug}/related", params: { limit: 3 }

      expect(related_ids).to eq(siblings.first(3).map(&:id))
    end

    it "deals the slots across the categories instead of exhausting the first" do
      review = create_review("Current", categories: [ burgundy, barossa ], days_ago: 1)
      # Burgundy has three reviews and Barossa one, so taking them in category
      # order would drop the Barossa one entirely.
      burgundy_a = create_review("Burgundy A", categories: [ burgundy ], days_ago: 2)
      burgundy_b = create_review("Burgundy B", categories: [ burgundy ], days_ago: 3)
      burgundy_c = create_review("Burgundy C", categories: [ burgundy ], days_ago: 4)
      barossa_a = create_review("Barossa A", categories: [ barossa ], days_ago: 5)

      get "/api/v1/reviews/#{review.slug}/related", params: { limit: 4 }

      expect(related_ids).to contain_exactly(burgundy_a.id, burgundy_b.id, burgundy_c.id, barossa_a.id)
      # The Barossa review is not last: it shares the rows with Burgundy.
      expect(related_ids.index(barossa_a.id)).to be < related_ids.index(burgundy_c.id)
    end

    it "lists a review that belongs to two of the categories only once" do
      review = create_review("Current", categories: [ burgundy, barossa ], days_ago: 1)
      both = create_review("Both", categories: [ burgundy, barossa ], days_ago: 2)
      burgundy_only = create_review("Burgundy only", categories: [ burgundy ], days_ago: 3)

      get "/api/v1/reviews/#{review.slug}/related"

      # "Both" is in the per-category list twice; it must survive the interleave
      # once, and the Burgundy-only sibling must still make the list.
      expect(related_ids).to contain_exactly(both.id, burgundy_only.id)
      expect(related_ids).to eq(related_ids.uniq)
    end

    it "hides other people's drafts from guests" do
      review = create_review("Current", days_ago: 1)
      published = create_review("Published sibling", days_ago: 2)
      draft = create_review("Someone else's draft", status: "draft", days_ago: 3)

      get "/api/v1/reviews/#{review.slug}/related"

      expect(related_ids).to eq([ published.id ])
      expect(related_ids).not_to include(draft.id)
    end

    it "includes drafts once signed in as a content manager" do
      review = create_review("Current", days_ago: 1)
      draft = create_review("Manager's draft", status: "draft", days_ago: 2)
      sign_in manager

      get "/api/v1/reviews/#{review.slug}/related"

      expect(related_ids).to include(draft.id)
    end

    it "returns 404 for an unknown review" do
      get "/api/v1/reviews/does-not-exist/related"
      expect(response).to have_http_status(:not_found)
    end
  end
end
