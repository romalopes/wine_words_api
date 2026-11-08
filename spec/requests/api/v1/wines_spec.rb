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
      expect(body["items"].map { |wine| wine["slug"] }).to eq([ wine_two.slug ])
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
      expect(body["capabilities"]).to eq(
        "update" => false, "destroy" => false, "add_vintage" => false
      )
    end

    it "returns 404 for a nonexistent wine" do
      get "/api/v1/wines/0"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "producer catalogue management" do
    let(:producer_owner) do
      User.create!(first_name: "Wine Owner", email: "wine-owner@example.com", password: "password123")
    end

    before do
      ProducerMembership.create!(user: producer_owner, producer: producer,
                                 membership_type: "owner", created_by: wine_manager)
      sign_in producer_owner
    end

    it "creates a wine with its first vintage for the linked producer" do
      post "/api/v1/wines", as: :json, params: {
        wine: {
          name: "Owner Cuvée", color: "Red", producer_id: producer.id,
          vintages_attributes: [ { year: 2024, no_vintage: false } ]
        }
      }

      expect(response).to have_http_status(:created)
      created = Wine.find_by!(name: "Owner Cuvée")
      expect(created.producer_id).to eq(producer.id)
      expect(created.vintages.pluck(:year)).to eq([ 2024 ])
    end

    it "returns producer-scoped management capabilities" do
      get "/api/v1/wines/#{wine_one.slug}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["capabilities"]).to eq(
        "update" => true, "destroy" => false, "add_vintage" => true
      )
    end

    it "cannot create a wine for an unrelated producer" do
      other_producer = Producer.create!(name: "Unrelated Wine Producer")

      post "/api/v1/wines", as: :json, params: {
        wine: { name: "Forbidden Cuvée", color: "Red", producer_id: other_producer.id }
      }

      expect(response).to have_http_status(:forbidden)
      expect(Wine.find_by(name: "Forbidden Cuvée")).to be_nil
    end

    it "cannot move an existing wine to another producer" do
      other_producer = Producer.create!(name: "Move Target Producer")

      patch "/api/v1/wines/#{wine_one.slug}", as: :json, params: {
        wine: { name: "Owner Updated Wine", producer_id: other_producer.id }
      }

      expect(response).to have_http_status(:ok)
      expect(wine_one.reload).to have_attributes(name: "Owner Updated Wine", producer_id: producer.id)
    end

    it "keeps contributors from creating wines" do
      contributor = User.create!(first_name: "Wine Contributor",
                                 email: "wine-contributor@example.com",
                                 password: "password123")
      ProducerMembership.create!(user: contributor, producer: producer,
                                 membership_type: "contributor", created_by: wine_manager)
      sign_in contributor

      post "/api/v1/wines", as: :json, params: {
        wine: { name: "Contributor Wine", color: "Red", producer_id: producer.id }
      }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
