require "rails_helper"

RSpec.describe "Api::V1::Wines", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:producer) { Producer.create!(name: "Penfolds", slug: "penfolds") }
  let(:wine_manager) do
    User.create!(first_name: "Manager", email: "wine-manager@example.com", password: "password123")
  end

  before { sign_in wine_manager }

  before do
    wine_manager.roles << Role.find_or_create_by!(name: "Admin")
  end

  describe "auto-assigned profile when no taste parameters are submitted" do
    def acidity
      @acidity ||= AutoAssignHelpers.make_taste_parameter("acidity", "Acidity")
    end

    def body_parameter
      @body ||= AutoAssignHelpers.make_taste_parameter("body", "Body")
    end

    it "links a profile by exact wine name and copies its taste scores" do
      profile = AutoAssignHelpers.make_profile("Pinot Noir")
      profile.wine_profile_taste_parameters.create!(taste_parameter: acidity, score: 4)
      profile.wine_profile_taste_parameters.create!(taste_parameter: body_parameter, score: 2)

      post "/api/v1/wines", params: { wine: { name: "Penfolds Pinot Noir", color: "Red", producer_id: producer.id } }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["wine_profile_id"]).to eq(profile.id)
      expect(response.parsed_body["wine_profile"]["name"]).to eq("Pinot Noir")

      wine = Wine.find_by(name: "Penfolds Pinot Noir")
      expect(wine.wine_profile).to eq(profile)
      expect(wine.wine_taste_parameters.count).to eq(2)
      expect(wine.wine_taste_parameters.find_by(taste_parameter: acidity).score).to eq(4)
      expect(wine.wine_taste_parameters.find_by(taste_parameter: body_parameter).score).to eq(2)
    end

    it "prefers an exact profile name match over grape matching" do
      wine_profile = AutoAssignHelpers.make_profile("Malbec", ["Malbec"], "Red")
      AutoAssignHelpers.make_profile("Cabernet Sauvignon")

      post "/api/v1/wines", params: { wine: { name: "Catena Malbec", color: "Red", producer_id: producer.id } }, as: :json

      expect(response).to have_http_status(:created)
      expect(Wine.find_by(name: "Catena Malbec").wine_profile).to eq(wine_profile)
    end

    it "falls back to grape matching when the name does not match" do
      AutoAssignHelpers.make_profile("Grenache")
      gsm = AutoAssignHelpers.make_profile("GSM", ["Grenache", "Shiraz", "Muscat"])
      gsm.wine_profile_taste_parameters.create!(taste_parameter: acidity, score: 3)
      AutoAssignHelpers.make_profile("Riesling")

      post "/api/v1/wines", params: { wine: { name: "Barossa Blend", color: "Red", producer_id: producer.id, grape_ids: gsm.wine_profile_grapes.pluck(:grape_id) } }, as: :json

      expect(response).to have_http_status(:created)
      wine = Wine.find_by(name: "Barossa Blend")
      expect(wine.wine_profile).to eq(gsm)
      expect(wine.wine_taste_parameters.find_by(taste_parameter: acidity).score).to eq(3)
    end

    it "leaves the wine untouched when no profile matches" do
      post "/api/v1/wines", params: { wine: { name: "Mysterious New Cuvée", color: "Red", producer_id: producer.id } }, as: :json

      expect(response).to have_http_status(:created)
      wine = Wine.find_by(name: "Mysterious New Cuvée")
      expect(wine.wine_profile).to be_nil
      expect(wine.wine_taste_parameters).to be_empty
    end

    it "links the profile and keeps the user's submitted taste scores" do
      profile = AutoAssignHelpers.make_profile("Pinot Noir")
      profile.wine_profile_taste_parameters.create!(taste_parameter: acidity, score: 4)

      post "/api/v1/wines", params: { wine: { name: "Pinot Noir with score", color: "Red", producer_id: producer.id, wine_profile_id: profile.id, wine_taste_parameters_attributes: [{ taste_parameter_id: acidity.id, score: 1 }] } }, as: :json

      expect(response).to have_http_status(:created)
      wine = Wine.find_by!(name: "Pinot Noir with score")
      expect(wine.wine_profile).to eq(profile)
      expect(wine.wine_taste_parameters.pluck(:score)).to eq([1])
    end

    it "honours an explicit wine_profile_id and copies from that profile" do
      profile = AutoAssignHelpers.make_profile("Pinot Noir")
      profile.wine_profile_taste_parameters.create!(taste_parameter: acidity, score: 4)

      post "/api/v1/wines", params: { wine: { name: "Explicit Pinot Noir", color: "Red", producer_id: producer.id, wine_profile_id: profile.id } }, as: :json

      expect(response).to have_http_status(:created)
      expect(Wine.find_by(name: "Explicit Pinot Noir").wine_profile).to eq(profile)
      expect(Wine.find_by(name: "Explicit Pinot Noir").wine_taste_parameters.find_by(taste_parameter: acidity).score).to eq(4)
    end

    it "returns 422 instead of 500 when an explicit profile id is invalid" do
      post "/api/v1/wines", params: { wine: { name: "Bad Profile", color: "Red", producer_id: producer.id, wine_profile_id: 999_999 } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
