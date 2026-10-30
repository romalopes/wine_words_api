require 'rails_helper'

RSpec.describe "Api::V1::Wines", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:producer) { Producer.create!(name: "Penfolds", slug: "penfolds") }
  let(:wine_manager) do
    User.create!(first_name: "Manager", email: "wine-manager@example.com", password: "password123")
  end

  before do
    wine_manager.roles << Role.find_or_create_by!(name: "Admin")
  end

  let(:taste_acidity) do
    TasteParameter.create!(slug: "acidity", label: "Acidity",
      label_1: "Low", label_2: "Medium (-)", label_3: "Medium",
      label_4: "Medium (+)", label_5: "High",
      help: "Brightness on the palate.")
  end
  let(:taste_body) do
    TasteParameter.create!(slug: "body", label: "Body",
      label_1: "Light", label_2: "Medium (-)", label_3: "Medium",
      label_4: "Medium (+)", label_5: "Full",
      help: "Weight of the wine.")
  end

  let!(:wine_one) do
    Wine.create! slug: "penfolds-bin-389",
      name: "Penfolds Bin 389", color: "Red",
      prompt: "Classic Australian cabernet shiraz.", producer: producer
  end
  let!(:wine_two) do
    Wine.create! slug: "tyrrells-vat-1-semillon",
      name: "Tyrrell's Vat 1 Semillon", color: "White",
      prompt: "Classic Hunter semillon.", producer: producer
  end
  before do
    WineTasteParameter.create!(wine: wine_one, taste_parameter: taste_acidity, score: 3)
    WineTasteParameter.create!(wine: wine_one, taste_parameter: taste_body, score: 5)
    WineTasteParameter.create!(wine: wine_two, taste_parameter: taste_acidity, score: 5)
    WineTasteParameter.create!(wine: wine_two, taste_parameter: taste_body, score: 1)
  end

  describe "GET /api/v1/wines" do
    it "filters producer wines before paginating and counting them" do
      other_producer = Producer.create!(name: "Other Estate")
      Wine.create! name: "A Different Wine", color: "Red", producer: other_producer

      get "/api/v1/wines", params: { producer_id: producer.id, page: 2, per_page: 1 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["total_count"]).to eq(2)
      expect(body["total_pages"]).to eq(2)
      expect(body["items"].map { |wine| wine["slug"] }).to eq([wine_two.slug])
    end

    it "returns no wines for a nonexistent producer" do
      get "/api/v1/wines", params: { producer_id: 0, page: 1, per_page: 20 }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("items" => [], "total_count" => 0)
    end

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
  end

  describe "GET /api/v1/wines/:id" do
    it "returns a specific wine" do
      get "/api/v1/wines/#{wine_one.id}"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq(wine_one.name)
    end

    it "returns 404 for a nonexistent wine" do
      get "/api/v1/wines/0"
      expect(response).to have_http_status(:not_found)
    end
  end
end