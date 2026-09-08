require "rails_helper"

# Request specs for Api::V1::CountriesController#index — the public country
# list used by the React Countries page. The frontend builds its links as
# `/countries/${country.slug}#producers` / `#wines`, so `slug` MUST be in
# the payload or every link degrades to `/countries/undefined`.
RSpec.describe "Api::V1::Countries", type: :request do
  describe "GET /api/v1/countries" do
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
