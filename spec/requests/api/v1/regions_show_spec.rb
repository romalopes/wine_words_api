require "rails_helper"

# Request specs for Api::V1::RegionsController#show. The payload carries the
# region's own fields plus the computed `full_path` — wines are NOT embedded
# (the client fetches them via GET /api/v1/wines?region_id=..., paginated).
RSpec.describe "Api::V1::Regions", type: :request do
  describe "GET /api/v1/regions/:slug" do
    let(:country) { Country.create!(name: "Regionland", code: "RL") }
    let(:region) { Region.create!(name: "Spec Valley", country: country) }

    it "returns region fields and full path without embedding wines" do
      producer = Producer.create!(name: "Valley Estate", country: country)
      wine = Wine.create!(name: "Valley Wine", color: "Red", producer: producer)
      wine.regions << region
      Vintage.create!(wine: wine, year: 2021)

      queries = []
      callback = ->(*args) { queries << args.last[:sql] }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get "/api/v1/regions/#{region.slug}"
      end

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["slug"]).to eq(region.slug)
      expect(body["country"]["id"]).to eq(country.id)
      expect(body["full_path"]).to be_present
      expect(body).not_to have_key("wines")
      # No wine payload means no image / category / vintage-count queries.
      expect(queries.grep(/FROM "(?:images|categories|vintages|active_storage_)"/)).to be_empty
    end

    it "is public (no auth required)" do
      get "/api/v1/regions/#{region.slug}"
      expect(response).to have_http_status(:ok)
    end

    it "renders not_found for unknown regions" do
      get "/api/v1/regions/does-not-exist"
      expect(response).to have_http_status(:not_found)
    end
  end
end