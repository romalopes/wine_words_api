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
    it "loads author and wine context with the reviews and reuses window counts" do
      queries = []
      callback = ->(*args) { queries << args.last[:sql] }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get "/api/v1/reviews/grouped"
      end
      expect(response).to have_http_status(:ok)
      expect(queries.grep(/SELECT COUNT\(\*\)/i)).to be_empty
      expect(queries.grep(/SELECT "(?:users|accounts|vintages|wines)"\.\*/)).to be_empty
      expect(queries.grep(/logs_enabled/)).to be_empty
    end

    it "keeps another user's drafts hidden from a reader with a bearer token" do
      reader = User.create!(first_name: "Reader", email: "token-reader@example.com", password: "password123")
      reader.roles << Role.find_or_create_by!(name: "Reader")
      token, = Warden::JWTAuth::UserEncoder.new.call(reader, :user, nil)
      get "/api/v1/reviews/grouped", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      titles = JSON.parse(response.body).flat_map { |group| group["reviews"].map { |item| item["title"] } }
      expect(titles).not_to include("Draft malbec")
    end

    # Image URLs must point straight at the storage service (presigned R2 in
    # prod, signed Disk path in test) instead of /blobs/redirect, so each image
    # no longer costs a Rails request per page view.
    it "serves review images as direct storage URLs, not blob redirects" do
      review = Review.find_by!(title: "A lovely malbec")
      image = Image.create!(imageable: review)
      image.file.attach(io: StringIO.new("fake"), filename: "grouped.png", content_type: "image/png")

      get "/api/v1/reviews/grouped"
      expect(response).to have_http_status(:ok)

      urls = JSON.parse(response.body).flat_map { |group| group["reviews"] }.flat_map { |item| item["images"] }
      expect(urls).to be_present
      urls.each { |url| expect(url).not_to include("/blobs/redirect") }
    end

    it "shows drafts to an admin authenticated only by a bearer token" do
      token, = Warden::JWTAuth::UserEncoder.new.call(manager, :user, nil)
      get "/api/v1/reviews/grouped", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      titles = JSON.parse(response.body).flat_map { |group| group["reviews"].map { |item| item["title"] } }
      expect(titles).to include("Draft malbec")
    end

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

    context "payload caching" do
      # The test env cache store is :null_store, which never caches; swap in a
      # MemoryStore so the caching behaviour itself can be asserted (the same
      # approach as categories_counts_spec).
      around do |example|
        original_cache = Rails.cache
        Rails.cache = ActiveSupport::Cache::MemoryStore.new
        example.run
        Rails.cache = original_cache
      end

      it "serves a repeat request for the same viewer from the cache" do
        get "/api/v1/reviews/grouped"
        expect(response).to have_http_status(:ok)

        queries = []
        callback = ->(*args) { queries << args.last[:sql] }
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          get "/api/v1/reviews/grouped"
        end

        expect(response).to have_http_status(:ok)
        expect(queries.grep(/FROM "reviews"/)).to be_empty
      end

      it "never serves one viewer's cached payload to another" do
        # The guest's entry holds no drafts; the manager's entry must be built
        # separately rather than reusing it.
        get "/api/v1/reviews/grouped"
        titles = JSON.parse(response.body).flat_map { |g| g["reviews"].map { |r| r["title"] } }
        expect(titles).not_to include("Draft malbec")

        sign_in manager
        get "/api/v1/reviews/grouped"
        titles = JSON.parse(response.body).flat_map { |g| g["reviews"].map { |r| r["title"] } }
        expect(titles).to include("Draft malbec")
      end
    end
  end
end
