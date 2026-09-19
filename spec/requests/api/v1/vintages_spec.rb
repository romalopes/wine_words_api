require "rails_helper"

# Request specs for vintage price persistence — the DB stores integer cents
# (price_cents) while the API speaks dollars via the virtual Vintage#price
# attribute. Covers the standalone vintage endpoint, the nested
# vintages_attributes path used by WineForm, and the serialized round-trip.
RSpec.describe "Vintage price (price_cents)", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:manager) do
    user = User.create!(user_name: "Manager", email: "manager@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end

  # Reviewers are wine managers too, so the reviewer who receives a wine package
  # may add the vintage of the wine straight from the item form.
  let(:reviewer) do
    user = User.create!(user_name: "Vintage Reviewer", email: "vintage-reviewer@example.com",
                        password: "password123")
    user.roles << Role.find_or_create_by!(name: "Reviewer")
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

  describe "authorization" do
    it "lets a Reviewer add a vintage" do
      sign_in reviewer

      post "/api/v1/wines/#{wine.slug}/vintages",
           params: { vintage: { year: 2023, no_vintage: false } }, as: :json

      expect(response).to have_http_status(:created)
      expect(wine.vintages.map(&:year)).to include(2023)
    end

    it "lets a Reviewer add an NV vintage (the year still validates)" do
      sign_in reviewer

      post "/api/v1/wines/#{wine.slug}/vintages",
           params: { vintage: { year: 2023, no_vintage: true } }, as: :json

      expect(response).to have_http_status(:created)
      expect(wine.vintages.find_by(year: 2023).no_vintage).to be true
    end

    it "still blocks users without a wine-manager role" do
      guest = User.create!(user_name: "Vintage Guest", email: "vintage-guest@example.com",
                           password: "password123")
      sign_in guest

      post "/api/v1/wines/#{wine.slug}/vintages",
           params: { vintage: { year: 2023 } }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(wine.vintages.count).to eq(0)
    end
  end
end