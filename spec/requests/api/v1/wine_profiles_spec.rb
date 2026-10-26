require 'rails_helper'

# Request specs for Api::V1::WineProfilesController
#
# The WineProfile model is the canonical wine catalogue that the React
# finder reads. These specs cover the full CRUD surface, the JSON
# serializer (which collapses the wine_profile_taste_parameters join
# rows into a slug -> score hash), and nested attributes behaviour.
RSpec.describe "Api::V1::WineProfiles", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:wine_manager) do
    User.create!(first_name: "Manager", email: "profile-manager@example.com", password: "password123")
  end

  before do
    sign_in wine_manager
  end

  let(:taste_acidity) { TasteParameter.create!(slug: "acidity", label: "Acidity", label_1: "Low", label_2: "Medium (-)", label_3: "Medium", label_4: "Medium (+)", label_5: "High", help: "Brightness on the palate.") }
  let(:taste_body)    { TasteParameter.create!(slug: "body",    label: "Body",    label_1: "Light", label_2: "Medium (-)", label_3: "Medium", label_4: "Medium (+)", label_5: "Full", help: "Weight of the wine.") }
  let!(:pinot_noir) { Grape.create!(name: "Pinot Noir") }
  let!(:chardonnay_grape) { Grape.create!(name: "Chardonnay") }
  let!(:tempranillo_grape) { Grape.create!(name: "Tempranillo") }
  let!(:france) { Country.create!(name: "France", code: "FR") }
  let!(:united_states) { Country.create!(name: "United States", code: "US") }
  let!(:spain) { Country.create!(name: "Spain", code: "ES") }
  let!(:burgundy) { Region.create!(name: "Burgundy", country: france) }
  let!(:oregon) { Region.create!(name: "Oregon", country: united_states) }
  let!(:rioja) { Region.create!(name: "Rioja", country: spain) }

  let!(:profile_one) do
    WineProfile.create!(
      slug: "pinot-noir",
      name: "Pinot Noir",
      color: "Red",
      notes: ['["cherry", "raspberry"]'],
      serving: "Pairs with roast chicken.",
    )
  end

  let!(:profile_two) do
    WineProfile.create!(
      slug: "chardonnay",
      name: "Chardonnay",
      color: "White",
      notes: ['["apple", "citrus"]'],
      serving: "Pairs with creamy pasta.",
    )
  end

  before do
    profile_one.profile_grapes << pinot_noir
    profile_one.profile_regions << [burgundy, oregon]
    profile_two.profile_grapes << chardonnay_grape
    profile_two.profile_regions << burgundy
    WineProfileTasteParameter.create!(wine_profile: profile_one, taste_parameter: taste_acidity, score: 4)
    WineProfileTasteParameter.create!(wine_profile: profile_one, taste_parameter: taste_body,    score: 2)
    WineProfileTasteParameter.create!(wine_profile: profile_two, taste_parameter: taste_acidity, score: 3)
    WineProfileTasteParameter.create!(wine_profile: profile_two, taste_parameter: taste_body,    score: 4)
  end

  describe "GET /api/v1/wine_profiles" do
    it "returns a successful response" do
      get "/api/v1/wine_profiles"
      expect(response).to have_http_status(:ok)
    end

    it "returns every wine profile" do
      get "/api/v1/wine_profiles"
      body = JSON.parse(response.body)
      expect(body.length).to eq(2)
      expect(body.map { |p| p["slug"] }).to match_array(%w[pinot-noir chardonnay])
    end

    it "uses WineProfileSerializer for each profile" do
      get "/api/v1/wine_profiles"
      body = JSON.parse(response.body)

      first = body.find { |p| p["slug"] == "pinot-noir" }
      expect(first).to include(
        "id" => profile_one.id,
        "slug"   => "pinot-noir",
        "name" => "Pinot Noir",
        "color" => "Red",
      )
      expect(first["parameters"]).to eq("acidity" => 4, "body" => 2)
    end

    it "exposes the grape and region data on each profile" do
      get "/api/v1/wine_profiles"
      first = JSON.parse(response.body).find { |p| p["slug"] == "pinot-noir" }
      expect(first).to have_key("grapes")
      expect(first).to have_key("regions")
      expect(first["grapes"]).not_to be_nil
      expect(first["regions"]).not_to be_nil
      expect(first["grapes"]).to eq(["Pinot Noir"])
      expect(first["regions"]).to match_array(["Burgundy", "Oregon"])
    end
  end

  describe "GET /api/v1/wine_profiles/:id" do
    it "returns the requested profile" do
      get "/api/v1/wine_profiles/#{profile_one.slug}"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("Pinot Noir")
      expect(body["parameters"]).to eq("acidity" => 4, "body" => 2)
    end

    it "returns 404 for a missing profile" do
      get "/api/v1/wine_profiles/does-not-exist"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/wine_profiles" do
    let(:valid_params) do
      {
        wine_profile: {
          slug: "tempranillo",
          name: "Tempranillo",
          color: "Red",
          grapes: ["Tempranillo"],
          regions: ["Rioja"],
          notes: '["cherry", "leather"]',
          serving: "Pairs with grilled lamb.",
        },
      }
    end

    it "creates a new profile and responds with 201 Created" do
      expect {
        post "/api/v1/wine_profiles", params: valid_params, as: :json
      }.to change(WineProfile, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it "persists the submitted attributes" do
      post "/api/v1/wine_profiles", params: valid_params, as: :json
      profile = WineProfile.find_by!(slug: "tempranillo")
      expect(profile.name).to eq("Tempranillo")
      expect(profile.color).to eq("Red")
      expect(profile.profile_grapes).to contain_exactly(tempranillo_grape)
      expect(profile.profile_regions).to contain_exactly(rioja)
    end

    it "ignores an attempted client-supplied slug and auto-generates a unique one" do
      # The controller's permitted params list does not allow `slug`, so
      # even if the client supplies one the model will auto-generate
      # from the name. The same name twice yields different slugs
      # because the model's callback appends a numeric suffix.
      post "/api/v1/wine_profiles", params: valid_params, as: :json
      expect {
        post "/api/v1/wine_profiles", params: valid_params, as: :json
      }.to change(WineProfile, :count).by(1)
      expect(response).to have_http_status(:created)
    end
  end

  describe "PATCH /api/v1/wine_profiles/:id" do
    it "updates an existing profile" do
      patch "/api/v1/wine_profiles/#{profile_one.slug}",
            params: { wine_profile: { name: "Pinot Noir (old vine)" } },
            as: :json
      expect(response).to have_http_status(:ok)
      expect(profile_one.reload.name).to eq("Pinot Noir (old vine)")
    end

    it "returns 404 for a missing profile" do
      patch "/api/v1/wine_profiles/missing",
            params: { wine_profile: { name: "x" } },
            as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/wine_profiles/:id" do
    it "destroys the profile and returns 204" do
      expect {
        delete "/api/v1/wine_profiles/#{profile_one.slug}"
      }.to change(WineProfile, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "also removes the wine_profile_taste_parameters join rows" do
      expect {
        delete "/api/v1/wine_profiles/#{profile_one.slug}"
      }.to change(WineProfileTasteParameter, :count).by(-2)
    end

    it "returns 404 for a missing profile" do
      delete "/api/v1/wine_profiles/missing"
      expect(response).to have_http_status(:not_found)
    end
  end
end
