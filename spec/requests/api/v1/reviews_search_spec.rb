require "rails_helper"
require "devise"

# Search and sorting for Api::V1::ReviewsController#index / #grouped — what the
# All Reviews page sends: one `query` term (full-text across the weighted
# vector) plus a `sort` value from the dropdown. Both endpoints must agree,
# because the page shows the grouped view until a category is picked.
RSpec.describe "Api::V1::Reviews search and sort", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:author) do
    User.create!(first_name: "Taster", email: "taster@example.com", password: "password123")
  end
  # A producer saved without a country auto-creates the default one (see
  # Producer::DEFAULT_COUNTRY_CODE), so this must reuse that row instead of
  # inserting a second "Australia"/"AU".
  let(:country) do
    Country.find_or_create_by!(code: Producer::DEFAULT_COUNTRY_CODE) { |c| c.name = "Australia" }
  end
  let(:region) { Region.create!(name: "Barossa Valley", country: country) }
  let(:producer) { Producer.create!(name: "Blefing Peak") }
  let(:category) { Category.create!(name: "Value") }

  # `self.producer` rather than `producer`: a keyword argument of the same name
  # shadows the `let` helper as a (nil) local.
  def create_wine(name, year, producer: self.producer)
    wine = Wine.create!(name: name, producer: producer, color: "Red")
    wine.regions << region
    Vintage.create!(wine: wine, year: year)
  end

  def create_review(title, vintage:, comment: nil, score: 90, status: "published", created_at: nil)
    review = Review.create!(vintage: vintage, user: author, title: title, comment: comment,
                            score: score, status: status)
    ReviewCategory.create!(review: review, category: category)
    review.update_columns(created_at: created_at) if created_at
    review.reload
  end

  def index_reviews(params = {})
    get "/api/v1/reviews", params: params
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)
  end

  def index_titles(params = {})
    index_reviews(params).map { |r| r["title"] }
  end

  def grouped_titles(params = {})
    get "/api/v1/reviews/grouped", params: params
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body).flat_map { |g| g["reviews"].map { |r| r["title"] } }
  end

  describe "GET /api/v1/reviews" do
    it "searches the tasting note, the wine, the producer and the vintage year" do
      shiraz = create_wine("Blefing Peak Shiraz", 2019, producer: Producer.create!(name: "Blefing Peak"))
      chardo = create_wine("Cold Harvest Chardonnay", 2021, producer: Producer.create!(name: "Cold Harvest"))
      create_review("Deep and dark", vintage: shiraz, comment: "Eucalypt and black fruit")
      create_review("Bright and tight", vintage: chardo)

      expect(index_titles(query: "eucalypt")).to eq(["Deep and dark"])
      expect(index_titles(query: "shiraz")).to eq(["Deep and dark"])
      expect(index_titles(query: "blefing")).to eq(["Deep and dark"])
      # Both wines share the region, so both reviews match at the same weight.
      expect(index_titles(query: "barossa")).to match_array(["Deep and dark", "Bright and tight"])
      expect(index_titles(query: "2021")).to eq(["Bright and tight"])
    end

    it "requires every word of a multi-word term, in any field" do
      shiraz = create_wine("Blefing Peak Shiraz", 2019)
      riesling = create_wine("Blefing Peak Riesling", 2019)
      create_review("Deep and dark", vintage: shiraz, comment: "Rich and peppery")
      create_review("Light and lemony", vintage: riesling)

      expect(index_titles(query: "blefing peppery")).to eq(["Deep and dark"])
    end

    it "matches prefixes so a partial word still finds the whole one" do
      create_review("Buttery", vintage: create_wine("Cold Harvest Chardonnay", 2021))
      create_review("Lean", vintage: create_wine("Cold Harvest Riesling", 2021))

      expect(index_titles(query: "chardon")).to eq(["Buttery"])
    end

    it "orders by relevance, putting the title hit above the tasting-note hit" do
      wine = create_wine("Blefing Peak Shiraz", 2019)
      # The term appears in one title (weight A) and in one comment (weight B).
      create_review("Peppery notes", vintage: wine, comment: "Violets and spice")
      create_review("Notes on violets", vintage: wine, comment: "Pepper and black fruit")

      expect(index_titles(query: "pepper")).to eq(["Peppery notes", "Notes on violets"])
    end

    it "accepts the deprecated `search` spelling of the term" do
      create_review("Deep and dark", vintage: create_wine("Blefing Peak Shiraz", 2019))

      expect(index_titles(search: "shiraz")).to eq(["Deep and dark"])
    end

    it "answers 200 with an unfiltered list for input that cannot be searched" do
      create_review("Deep and dark", vintage: create_wine("Blefing Peak Shiraz", 2019))

      # Operators used to reach to_tsquery untouched, which raised and 500ed.
      expect(index_titles(query: " & : ' !")).to eq(["Deep and dark"])
      expect(index_titles(query: "a")).to eq(["Deep and dark"])
    end
  end

  describe "GET /api/v1/reviews sorting" do
    let(:wine) { create_wine("Blefing Peak Shiraz", 2019) }

    before do
      create_review("Latest, mid score", vintage: wine, score: 92, created_at: 1.hour.ago)
      create_review("Older, best score", vintage: wine, score: 95, created_at: 3.days.ago)
      create_review("Middle, worst score", vintage: wine, score: 88, created_at: 2.days.ago)
    end

    it "sorts newest first by default" do
      expect(index_titles).to eq(["Latest, mid score", "Middle, worst score", "Older, best score"])
    end

    it "honours recent and oldest" do
      expect(index_titles(sort: "recent"))
        .to eq(["Latest, mid score", "Middle, worst score", "Older, best score"])
      expect(index_titles(sort: "oldest"))
        .to eq(["Older, best score", "Middle, worst score", "Latest, mid score"])
    end

    it "honours score_high and score_low" do
      expect(index_titles(sort: "score_high"))
        .to eq(["Older, best score", "Latest, mid score", "Middle, worst score"])
      expect(index_titles(sort: "score_low"))
        .to eq(["Middle, worst score", "Latest, mid score", "Older, best score"])
    end

    it "treats an unknown sort as the default rather than trusting it" do
      expect(index_titles(sort: "created_at DESC; DROP TABLE reviews"))
        .to eq(["Latest, mid score", "Middle, worst score", "Older, best score"])
    end

    it "ranks matches above recency for relevance, which is what the dropdown implies" do
      create_review("Pepper, perfectly pitched", vintage: wine, score: 85, created_at: 5.days.ago)
      create_review("Latest, mid score", vintage: wine, score: 92, comment: "A hint of pepper")

      # Recency would put "Latest, mid score" first; the title hit must win.
      expect(index_titles(query: "pepper", sort: "relevance").first)
        .to eq("Pepper, perfectly pitched")
    end
  end

  describe "GET /api/v1/reviews/grouped" do
    let(:wine) { create_wine("Blefing Peak Shiraz", 2019) }

    before do
      create_review("Peppery notes", vintage: wine, score: 95, created_at: 1.day.ago)
      create_review("Notes on violets", vintage: wine, score: 88,
                    comment: "Pepper and black fruit", created_at: 2.days.ago)
      create_review("Unrelated", vintage: wine, score: 90, created_at: 3.days.ago)
    end

    it "agrees with the feed about what matches, and in what order" do
      expect(grouped_titles(query: "pepper")).to eq(index_titles(query: "pepper"))
      expect(grouped_titles(query: "pepper")).to eq(["Peppery notes", "Notes on violets"])
    end

    it "honours the sort param inside each category" do
      expect(grouped_titles(query: "pepper", sort: "score_low"))
        .to eq(["Notes on violets", "Peppery notes"])
      expect(grouped_titles(sort: "score_high"))
        .to eq(["Peppery notes", "Unrelated", "Notes on violets"])
    end

    it "keeps drafts invisible while searching, for guests and for their own author" do
      create_review("Pepper draft", vintage: wine, score: 99, status: "draft")

      expect(grouped_titles(query: "pepper")).to eq(["Peppery notes", "Notes on violets"])
      expect(index_titles(query: "pepper")).to eq(["Peppery notes", "Notes on violets"])
    end

    it "answers 200 and skips filtering for input that cannot be searched" do
      expect(grouped_titles(query: "<> & !")).to eq(index_titles(sort: "recent"))
    end
  end
end
