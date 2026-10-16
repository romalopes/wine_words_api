require "rails_helper"

# Request specs for Api::V1::GrapesController#show. The payload is lean:
# grape fields plus wines_count / producers_count. Wines are NOT embedded —
# the React grape screens fetch them via GET /api/v1/wines?grape_id=...
# (paginated, WineListSerializer). Embedding every wine with the full
# WineSerializer used to cost a query per image/category/vintage-count
# (2195 queries and a 179 s response for chardonnay).
RSpec.describe "Api::V1::Grapes", type: :request do
  describe "GET /api/v1/grapes/:slug" do
    let(:grape) { Grape.create!(name: "Spec Chardonnay", color: "white") }

    def seed_wine(name)
      producer = Producer.create!(name: "#{name} Estate")
      producer.grapes << grape
      wine = Wine.create!(name: name, color: "White", producer: producer)
      wine.grapes << grape
      Vintage.create!(wine: wine, year: 2020)
      wine
    end

    it "returns grape fields and counts without embedding wines" do
      seed_wine("Chard Wine One")
      seed_wine("Chard Wine Two")

      queries = []
      callback = ->(*args) { queries << args.last[:sql] }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get "/api/v1/grapes/#{grape.slug}"
      end

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["slug"]).to eq(grape.slug)
      expect(body["wines_count"]).to eq(2)
      expect(body["producers_count"]).to eq(2)
      expect(body).not_to have_key("wines")
      # No wine payload means no image / category / vintage-count queries.
      expect(queries.grep(/FROM "(?:images|categories|vintages|active_storage_)"/)).to be_empty
    end

    it "is public (no auth required)" do
      get "/api/v1/grapes/#{grape.slug}"
      expect(response).to have_http_status(:ok)
    end

    it "renders not_found for unknown grapes" do
      get "/api/v1/grapes/does-not-exist"
      expect(response).to have_http_status(:not_found)
    end
  end
end