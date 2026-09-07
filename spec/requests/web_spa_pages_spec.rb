require "rails_helper"

# Smoke tests for the SPA-style public pages (mirroring the React app's
# /finder, /quiz, /search, /about and /subscribe routes).
RSpec.describe "Web SPA pages", type: :request do
  describe "GET /about" do
    it "renders the About page" do
      get "/about"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("About Wine Words")
    end
  end

  describe "GET /quiz" do
    before do
      TasteParameter.create!(slug: "acidity", label: "Acidity", low: "Soft", high: "Sharp")
    end

    it "renders the quiz and its taste parameters" do
      get "/quiz"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tasting Quiz")
      expect(response.body).to include('data-controller="quiz"')
      expect(response.body).to include("acidity")
    end
  end

  describe "GET /quiz/search" do
    it "returns an empty array for a blank query" do
      get "/quiz/search", params: { q: "" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end

    it "finds a matching wine profile" do
      acidity = TasteParameter.create!(slug: "acidity", label: "Acidity", low: "Soft", high: "Sharp")
      profile = WineProfile.create!(name: "Shiraz Special", color: "Red", regions: "Barossa Valley")
      profile.wine_profile_taste_parameters.create!(taste_parameter: acidity, score: 4)

      get "/quiz/search", params: { q: "Shiraz" }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(1)
      expect(body.first["name"]).to eq("Shiraz Special")
      expect(body.first["parameters"]).to eq("acidity" => 4)
    end
  end

  describe "GET /search" do
    it "renders the search page" do
      get "/search"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Search Wines")
      expect(response.body).to include('data-controller="wine-search"')
    end
  end

  describe "GET /search/results" do
    before do
      producer = Producer.create!(name: "Test Producer #{rand(100_000)}", email: "p#{rand(100_000)}@example.com")
      producer.wines.create!(name: "Global-Search-Wine #{rand(100_000)}", color: "Red", prompt: "x")
    end

    it "returns matches by name for a query" do
      wine = Wine.last
      get "/search/results", params: { query: wine.name.split.first }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.map { |w| w["name"] }).to include(wine.name)
    end

    it "returns matches by producer name for a query" do
      wine = Wine.last
      get "/search/results", params: { query: wine.producer.name.split.first }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.map { |w| w["name"] }).to include(wine.name)
    end

    it "returns an empty array for a blank query" do
      get "/search/results", params: { query: "" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end
  end

  describe "GET /finder" do
    before do
      TasteParameter.create!(slug: "acidity", label: "Acidity", low: "Soft", high: "Sharp")
    end

    it "renders the finder with sliders" do
      get "/finder"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Identify a wine from how it tastes")
      expect(response.body).to include("taste_acidity")
    end
  end

  describe "GET /finder/matches" do
    before do
      acidity = TasteParameter.create!(slug: "acidity", label: "Acidity", low: "Soft", high: "Sharp")
      profile = WineProfile.create!(name: "Bright White", color: "White", grapes: "Sauvignon Blanc", regions: "Marlborough")
      profile.wine_profile_taste_parameters.create!(taste_parameter: acidity, score: 1)
    end

    it "ranks and renders matching profiles without the layout" do
      get "/finder/matches", params: { taste_acidity: "1" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bright White")
      expect(response.body).to include("100%")
    end
  end

  describe "GET /subscribe" do
    it "renders the subscribe page" do
      get "/subscribe"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Subscriptions")
    end

    it "requires sign-in to create" do
      post "/subscribe", params: { subscription_id: 1 }
      expect(response).to redirect_to(login_path)
    end
  end
end