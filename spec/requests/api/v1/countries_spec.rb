require "rails_helper"

# Request specs for Api::V1::CountriesController#index — the public country
# list used by the React Countries page. The frontend builds its links as
# `/countries/${country.slug}#producers` / `#wines`, so `slug` MUST be in
# the payload or every link degrades to `/countries/undefined`.
RSpec.describe "Api::V1::Countries", type: :request do
  describe "GET /api/v1/countries" do
    it "skips wine counts for the producer filter but keeps them by default" do
      country = Country.create!(name: "Countland", code: "CL")
      producer = Producer.create!(name: "Count Estate", country: country)
      Wine.create!(name: "Count Wine", color: "Red", producer: producer)
      queries = []
      callback = ->(*args) { queries << args.last[:sql] }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get "/api/v1/countries", params: { include_wine_counts: false }
      end
      expect(response).to have_http_status(:ok)
      item = JSON.parse(response.body).find { |row| row["id"] == country.id }
      expect(item).to include("producers_count" => 1)
      expect(item).not_to have_key("wines_count")
      expect(queries.grep(/FROM "wines"/)).to be_empty

      get "/api/v1/countries"
      item = JSON.parse(response.body).find { |row| row["id"] == country.id }
      expect(item).to include("producers_count" => 1, "wines_count" => 1)
    end

    it "is public (no auth required) and returns an array" do
      get "/api/v1/countries"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to be_an(Array)
    end

    it "includes slug for every country so frontend links resolve" do
      Country.create!(name: "Sluggania", code: "SG")
      get "/api/v1/countries"
      body = JSON.parse(response.body)

      expect(body).not_to be_empty
      body.each do |country|
        expect(country).to include("slug")
        expect(country["slug"]).to be_a(String)
        expect(country["slug"]).not_to be_empty
      end
    end
  end
end
