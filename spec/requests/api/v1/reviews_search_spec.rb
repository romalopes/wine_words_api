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

  def create_review(title, vintage:, comment: nil, score: 90, status: "published", created_at: nil, user: self.author)
    review = Review.create!(vintage: vintage, user: user, title: title, comment: comment,
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

  # The Reviews page filters by lifecycle (All / Draft / Published) client-side
  # today, which silently drops drafts that fall outside the grouped view's
  # per-category cap. These pin the server-side status filter both endpoints now
  # honour, so a manager's Draft tab returns the real drafts.
  describe "status filter" do
    let(:wine) { create_wine("Blefing Peak Shiraz", 2019) }
    let(:manager) do
      user = User.create!(first_name: "Manager", email: "status-manager@example.com",
                          password: "password123")
      user.roles << Role.find_or_create_by!(name: "Admin")
      user
    end

    before do
      create_review("Published one", vintage: wine, score: 90, created_at: 2.days.ago)
      create_review("Draft one", vintage: wine, score: 91, status: "draft", created_at: 1.day.ago)
      create_review("Archived one", vintage: wine, score: 92, status: "archived", created_at: 3.days.ago)
    end

    it "returns only drafts for the feed when a manager asks for status=draft" do
      sign_in manager
      expect(index_titles(status: "draft")).to eq(["Draft one"])
    end

    it "returns only drafts for the grouped view when a manager asks for status=draft" do
      sign_in manager
      expect(grouped_titles(status: "draft")).to eq(["Draft one"])
    end

    it "returns only published for status=published" do
      sign_in manager
      expect(index_titles(status: "published")).to eq(["Published one"])
    end

    it "ignores an unwhitelisted status value instead of trusting it" do
      sign_in manager
      # A garbage value must not filter (nor execute as SQL) — it behaves as if
      # no status was sent, so the manager sees every review.
      expect(index_titles(status: "draft OR 1=1"))
        .to match_array(["Published one", "Draft one", "Archived one"])
    end

    it "still hides another user's drafts from a reader even when status=draft is requested" do
      reader = User.create!(first_name: "Reader", email: "status-reader@example.com",
                            password: "password123")
      reader.roles << Role.find_or_create_by!(name: "Reader")
      sign_in reader
      expect(index_titles(status: "draft")).to eq([])
    end
  end

  # The "My Reviews" tab renders through the same grouped / paginated endpoints as
  # "All Reviews", scoped to the signed-in author via `scope=mine`. Previously it
  # hit /reviews/my_reviews, which shipped the author's entire unpaginated library
  # and was slower than "All Reviews".
  describe "scope=mine" do
    let(:wine) { create_wine("Blefing Peak Shiraz", 2019) }
    let(:me) do
      User.create!(first_name: "Me", email: "scope-me@example.com", password: "password123")
    end
    let(:someone_else) do
      User.create!(first_name: "Other", email: "scope-other@example.com", password: "password123")
    end

    before do
      create_review("Mine, published", vintage: wine, user: me, created_at: 2.days.ago)
      create_review("Mine, draft", vintage: wine, user: me, status: "draft", created_at: 1.day.ago)
      create_review("Theirs, published", vintage: wine, user: someone_else, created_at: 3.days.ago)
    end

    it "returns only the signed-in user's reviews for the feed" do
      sign_in me
      expect(index_titles(scope: "mine"))
        .to match_array(["Mine, published", "Mine, draft"])
    end

    it "returns only the signed-in user's reviews for the grouped view, drafts included" do
      sign_in me
      expect(grouped_titles(scope: "mine"))
        .to match_array(["Mine, published", "Mine, draft"])
    end

    it "combines scope=mine with the status filter" do
      sign_in me
      expect(index_titles(scope: "mine", status: "draft")).to eq(["Mine, draft"])
    end

    it "ignores scope=mine when nobody is signed in" do
      # No current_user, so the guard skips the filter and the guest only sees
      # published reviews (via visible_to) — never a 500 or a leaked draft.
      expect(index_titles(scope: "mine")).to match_array(["Mine, published", "Theirs, published"])
    end
  end
end
