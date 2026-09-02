require "rails_helper"

# Request specs for vintage price persistence — the DB stores integer cents
# (price_cents) while the API speaks dollars via the virtual Vintage#price
# attribute. Covers the standalone vintage endpoint, the nested
# vintages_attributes path used by WineForm, and the serialized round-trip.
RSpec.describe "Vintage price (price_cents)", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:manager) do
    user = User.create!(name: "Manager", email: "manager@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Super User")
    user
  end

  let(:producer) { Producer.create!(name: "Vintage Spec Producer") }
  let(:wine) do
    Wine.create!(name: "Vintage Spec Wine", color: "red", producer: producer)
  end

  before { sign_in manager }

  describe "POST /api/v1/wines/:wine_id/vintages" do
    it "saves the price as cents and returns dollars" do
      post "/api/v1/wines/#{wine.slug}/vintages",
           params: { vintage: { year: 2020, prompt: "great", price: "45.55", no_vintage: false } },
           as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["price"]).to eq(45.55)

      vintage = wine.vintages.find_by(year: 2020)
      expect(vintage.price_cents).to eq(4555)
    end

    it "allows a nil price" do
      post "/api/v1/wines/#{wine.slug}/vintages",
           params: { vintage: { year: 2021, price: nil, no_vintage: false } }, as: :json

      expect(response).to have_http_status(:created)
      expect(wine.vintages.find_by(year: 2021).price_cents).to be_nil
    end
  end

  describe "nested vintages_attributes (WineForm path)" do
    it "saves price on create via nested attributes" do
      patch "/api/v1/wines/#{wine.slug}",
            params: { wine: { vintages_attributes: [{ year: 2019, price: "31.10", no_vintage: false }] } },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(wine.vintages.find_by(year: 2019).price_cents).to eq(3110)
    end

    it "updates the price of an existing vintage" do
      vintage = wine.vintages.create!(year: 2018, price: "20.00")
      patch "/api/v1/wines/#{wine.slug}",
            params: { wine: { vintages_attributes: [{ id: vintage.id, year: 2018, price: "25.50" }] } },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(vintage.reload.price_cents).to eq(2550)
    end

    it "round-trips the price through the wine serializer" do
      wine.vintages.create!(year: 2017, price: "12.34")
      get "/api/v1/wines/#{wine.slug}"

      vintage_json = JSON.parse(response.body)["vintages"].find { |v| v["year"] == 2017 }
      expect(vintage_json["price"]).to eq(12.34)
    end
  end
end