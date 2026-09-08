require 'rails_helper'

# Request specs for Api::V1::WinesController
#
# Exercises the JSON endpoints the React frontend (and any third-party
# client) relies on. Each example resets the database via the
# transactional fixtures provided by RSpec, so examples can be run in
# any order without leaking state.
RSpec.describe "Api::V1::Wines", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:producer) { Producer.create!(name: "Penfolds", slug: "penfolds") }
  let(:wine_manager) do
    User.create!(name: "Manager", email: "wine-manager@example.com", password: "password123")
  end

  before do
    wine_manager.roles << Role.find_or_create_by!(name: "Admin")
  end

  let(:taste_acidity) { TasteParameter.create!(slug: "acidity", label: "Acidity", low: "Soft", high: "Sharp", help: "Brightness on the palate.") }
  let(:taste_body)    { TasteParameter.create!(slug: "body",    label: "Body",    low: "Light", high: "Full", help: "Weight of the wine.") }

  let!(:wine_one) do
    Wine.create!(
      slug: "penfolds-bin-389",
      name: "Penfolds Bin 389",
      color: "Red",
      prompt: "Classic Australian cabernet shiraz.",
      producer: producer,
    )
  end

  let!(:wine_two) do
    Wine.create!(
      slug: "tyrrells-vat-1-semillon",
      name: "Tyrrell's Vat 1 Semillon",
      color: "White",
      prompt: "Classic Hunter semillon.",
      producer: producer,
    )
  end

  before do
    WineTasteParameter.create!(wine: wine_one, taste_parameter: taste_acidity, score: 3)
    WineTasteParameter.create!(wine: wine_one, taste_parameter: taste_body,    score: 5)
    WineTasteParameter.create!(wine: wine_two, taste_parameter: taste_acidity, score: 5)
    WineTasteParameter.create!(wine: wine_two, taste_parameter: taste_body,    score: 1)
  end

  describe "GET /api/v1/wines" do
    it "returns a successful response" do
      get "/api/v1/wines"
      expect(response).to have_http_status(:ok)
    end

    it "returns both wines in the catalogue" do
      get "/api/v1/wines"
      body = JSON.parse(response.body)
      expect(body).to be_an(Array)
      expect(body.length).to eq(2)
    end

    it "serializes each wine through WineListSerializer" do
      get "/api/v1/wines"
      body = JSON.parse(response.body)

      first = body.find { |w| w["slug"] == wine_one.slug }
      expect(first).to include(
        "name"     => "Penfolds Bin 389",
        "color"    => "Red",
        "sparkling" => false,
      )
      expect(first["producer"]["name"]).to eq("Penfolds")
      expect(first["vintages_count"]).to eq(0)
    end

    it "uses the wine slug, not the database id, as the public id" do
      get "/api/v1/wines"
      slugs = JSON.parse(response.body).map { |w| w["slug"] }
      expect(slugs).to match_array([wine_one.slug, wine_two.slug])
      expect(slugs).not_to include(wine_one.id, wine_two.id)
    end
  end

  describe "GET /api/v1/wines/:id" do
    it "returns a successful response for an existing wine" do
      get "/api/v1/wines/#{wine_one.slug}"
      expect(response).to have_http_status(:ok)
    end

    it "returns the serialized wine data" do
      get "/api/v1/wines/#{wine_one.slug}"
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("Penfolds Bin 389")
      expect(body["parameters"]).to contain_exactly(
        { "id" => anything, "taste_parameter_id" => taste_acidity.id, "taste_parameter_slug" => "acidity", "score" => 3 },
        { "id" => anything, "taste_parameter_id" => taste_body.id, "taste_parameter_slug" => "body", "score" => 5 }
      )
    end

    it "returns 404 for a missing wine" do
      get "/api/v1/wines/does-not-exist"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/wines" do
    before { sign_in wine_manager }

    let(:valid_params) do
      {
        wine: {
          name: "Henschke Hill of Grace",
          color: "Red",
          prompt: "Old-vine shiraz.",
          producer_id: producer.id,
        },
      }
    end

    it "creates a new wine and returns 201 Created" do
      expect {
        post "/api/v1/wines", params: valid_params, as: :json
      }.to change(Wine, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it "persists the submitted attributes" do
      post "/api/v1/wines", params: valid_params, as: :json
      wine = Wine.find_by!(slug: "henschke-hill-of-grace")
      expect(wine.name).to eq("Henschke Hill of Grace")
      expect(wine.color).to eq("Red")
      expect(wine.prompt).to eq("Old-vine shiraz.")
    end

    it "returns 422 with error details when attributes are invalid" do
      post "/api/v1/wines", params: { wine: { name: "", color: "" } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to be_a(Hash)
    end
  end

  describe "PATCH /api/v1/wines/:id" do
    before { sign_in wine_manager }

    it "updates an existing wine and returns 200 OK" do
      patch "/api/v1/wines/#{wine_one.slug}",
            params: { wine: { prompt: "Updated prompt" } },
            as: :json
      expect(response).to have_http_status(:ok)
      expect(wine_one.reload.prompt).to eq("Updated prompt")
    end

    it "returns 422 when the update is invalid" do
      patch "/api/v1/wines/#{wine_one.slug}",
            params: { wine: { name: "" } },
            as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 for a missing wine" do
      patch "/api/v1/wines/missing", params: { wine: { name: "x" } }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/wines/:id" do
    before { sign_in wine_manager }

    it "destroys the wine and returns 204 No Content" do
      expect {
        delete "/api/v1/wines/#{wine_one.slug}"
      }.to change(Wine, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "also removes the wine's taste parameter join rows" do
      expect {
        delete "/api/v1/wines/#{wine_one.slug}"
      }.to change(WineTasteParameter, :count).by(-2)
    end

    it "returns 404 for a missing wine" do
      delete "/api/v1/wines/missing"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/wines/advanced_search" do
    let!(:review_user) { User.create!(name: "Reviewer", email: "adv-search@example.com", password: "password123") }

    before do
      wine_one.update!(producer: producer, sparkling: true, alcohol_percentage: 14.5)
      wine_two.update!(producer: producer, alcohol_percentage: 11.5)

      Vintage.create!(wine: wine_one, year: 2018, price_cents: 9_000)
      old_vintage = Vintage.create!(wine: wine_one, year: 2017, price_cents: 8_000)
      latest_vintage = Vintage.create!(wine: wine_two, year: 2020, price_cents: 12_000)

      Review.create!(
        vintage: latest_vintage,
        user: review_user,
        title: "Great semillon",
        score: 95,
        status: "published",
        published_at: Time.zone.local(2024, 3, 1, 12),
        drink_from: 2025,
        drink_to: 2032,
      )
      # Draft review on the older vintage of wine_one — must be ignored by
      # review filters that target the latest reviewed vintage.
      Review.create!(
        vintage: old_vintage,
        user: review_user,
        title: "Old bin",
        score: 60,
        status: "draft",
      )
    end

    def search(params)
      get "/api/v1/wines/advanced_search", params: params
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end

    it "returns all wines when no filters are given" do
      body = search({})
      slugs = body.map { |w| w["slug"] }
      expect(slugs).to contain_exactly(wine_one.slug, wine_two.slug)
    end

    it "filters by wine name (case-insensitive partial)" do
      body = search({ name: "vat 1" })
      expect(body.map { |w| w["slug"] }).to eq([wine_two.slug])
    end

    it "filters by producer name" do
      body = search({ producer_name: "penfolds" })
      expect(body.length).to eq(2)
    end

    it "filters by color" do
      body = search({ color: "Red" })
      expect(body.map { |w| w["slug"] }).to eq([wine_one.slug])
    end

    it "filters by sparkling" do
      body = search({ sparkling: "true" })
      expect(body.map { |w| w["slug"] }).to eq([wine_one.slug])

      body = search({ sparkling: "false" })
      expect(body.map { |w| w["slug"] }).to eq([wine_two.slug])
    end

    it "filters by alcohol percentage range" do
      body = search({ alcohol_min: "12", alcohol_max: "15" })
      expect(body.map { |w| w["slug"] }).to eq([wine_one.slug])
    end

    it "filters by vintage year range" do
      body = search({ vintage_year_min: "2019" })
      expect(body.map { |w| w["slug"] }).to eq([wine_two.slug])
    end

    it "filters by price range (dollars, stored as cents)" do
      body = search({ price_min: "100", price_max: "200" })
      expect(body.map { |w| w["slug"] }).to eq([wine_two.slug])
    end

    it "filters by review score of the last reviewed vintage" do
      body = search({ score_min: "90" })
      expect(body.map { |w| w["slug"] }).to eq([wine_two.slug])
    end

    it "filters by published date range" do
      body = search({ published_from: "2024-02-01", published_to: "2024-04-01" })
      expect(body.map { |w| w["slug"] }).to eq([wine_two.slug])

      body = search({ published_from: "2025-01-01" })
      expect(body).to be_empty
    end

    it "filters by drink-from / drink-to ranges of the last review" do
      body = search({ drink_from_min: "2024", drink_to_max: "2035" })
      expect(body.map { |w| w["slug"] }).to eq([wine_two.slug])
    end

    it "filters by taste parameter score range" do
      body = search({ acidity_min: "0", acidity_max: "4" })
      expect(body.map { |w| w["slug"] }).to eq([wine_one.slug])

      body = search({ body_min: "4" })
      expect(body.map { |w| w["slug"] }).to eq([wine_one.slug])
    end

    it "combines filters with AND" do
      body = search({ color: "Red", sparkling: "true", alcohol_min: "14" })
      expect(body.map { |w| w["slug"] }).to eq([wine_one.slug])

      body = search({ color: "Red", score_min: "90" })
      expect(body).to be_empty
    end

    it "paginates when a page param is given" do
      body = search({ page: "1", per_page: "1" })
      expect(body).to include("items", "total_count", "total_pages")
      expect(body["total_count"]).to eq(2)
      expect(body["items"].length).to eq(1)
    end

    it "ignores invalid numeric/date values instead of failing" do
      body = search({ alcohol_min: "abc", published_from: "not-a-date" })
      expect(body.length).to eq(2)
    end
  end
end
