require 'rails_helper'

# Request specs for Api::V1::WinesController
#
# Exercises the JSON endpoints the React frontend (and any third-party
# client) relies on. Each example resets the database via the
# transactional fixtures provided by RSpec, so examples can be run in
# any order without leaking state.
RSpec.describe "Api::V1::Wines", type: :request do
  let(:taste_acidity) { TasteParameter.create!(slug: "acidity", label: "Acidity", low: "Soft", high: "Sharp", help: "Brightness on the palate.") }
  let(:taste_body)    { TasteParameter.create!(slug: "body",    label: "Body",    low: "Light", high: "Full", help: "Weight of the wine.") }

  let!(:wine_one) do
    Wine.create!(
      slug: "penfolds-bin-389",
      name: "Penfolds Bin 389",
      color: "Red",
      prompt: "Classic Australian cabernet shiraz.",
    )
  end

  let!(:wine_two) do
    Wine.create!(
      slug: "tyrrells-vat-1-semillon",
      name: "Tyrrell's Vat 1 Semillon",
      color: "White",
      prompt: "Classic Hunter semillon.",
    )
  end

  before do
    WineTasteParameter.create!(wine: wine_one, taste_parameter: taste_acidity, score: 3)
    WineTasteParameter.create!(wine: wine_one, taste_parameter: taste_body,    score: 5)
    WineTasteParameter.create!(wine: wine_two, taste_parameter: taste_acidity, score: 5)
    WineTasteParameter.create!(wine: wine_two, taste_parameter: taste_body,    score: 1)
  end

  describe "GET /api/v1/wines" do
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

    it "serializes each wine through WineSerializer" do
      get "/api/v1/wines"
      body = JSON.parse(response.body)

      first = body.find { |w| w["slug"] == wine_one.slug }
      expect(first).to include(
        "name"   => "Penfolds Bin 389",
        "color"  => "Red",
        "prompt" => "Classic Australian cabernet shiraz.",
      )
      expect(first["parameters"]).to eq(
        "acidity" => 3,
        "body"    => 5,
      )
    end

    it "uses the wine slug, not the database id, as the public id" do
      get "/api/v1/wines"
      slugs = JSON.parse(response.body).map { |w| w["slug"] }
      expect(slugs).to match_array([wine_one.slug, wine_two.slug])
      expect(slugs).not_to include(wine_one.id, wine_two.id)
    end
  end

  describe "GET /api/v1/wines/:id" do
    it "returns a successful response for an existing wine" do
      get "/api/v1/wines/#{wine_one.slug}"
      expect(response).to have_http_status(:ok)
    end

    it "returns the serialized wine data" do
      get "/api/v1/wines/#{wine_one.slug}"
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("Penfolds Bin 389")
      expect(body["parameters"]).to eq("acidity" => 3, "body" => 5)
    end

    it "returns 404 for a missing wine" do
      get "/api/v1/wines/does-not-exist"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/wines" do
    let(:valid_params) do
      {
        wine: {
          name: "Henschke Hill of Grace",
          color: "Red",
          prompt: "Old-vine shiraz.",
        },
      }
    end

    it "creates a new wine and returns 201 Created" do
      expect {
        post "/api/v1/wines", params: valid_params, as: :json
      }.to change(Wine, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it "persists the submitted attributes" do
      post "/api/v1/wines", params: valid_params, as: :json
      wine = Wine.find_by!(slug: "henschke-hill-of-grace")
      expect(wine.name).to eq("Henschke Hill of Grace")
      expect(wine.color).to eq("Red")
      expect(wine.prompt).to eq("Old-vine shiraz.")
    end

    it "returns 422 with error details when attributes are invalid" do
      post "/api/v1/wines", params: { wine: { name: "", color: "" } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to be_a(Hash)
    end
  end

  describe "PATCH /api/v1/wines/:id" do
    it "updates an existing wine and returns 200 OK" do
      patch "/api/v1/wines/#{wine_one.slug}",
            params: { wine: { prompt: "Updated prompt" } },
            as: :json
      expect(response).to have_http_status(:ok)
      expect(wine_one.reload.prompt).to eq("Updated prompt")
    end

    it "returns 422 when the update is invalid" do
      patch "/api/v1/wines/#{wine_one.slug}",
            params: { wine: { name: "" } },
            as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 for a missing wine" do
      patch "/api/v1/wines/missing", params: { wine: { name: "x" } }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/wines/:id" do
    it "destroys the wine and returns 204 No Content" do
      expect {
        delete "/api/v1/wines/#{wine_one.slug}"
      }.to change(Wine, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "also removes the wine's taste parameter join rows" do
      expect {
        delete "/api/v1/wines/#{wine_one.slug}"
      }.to change(WineTasteParameter, :count).by(-2)
    end

    it "returns 404 for a missing wine" do
      delete "/api/v1/wines/missing"
      expect(response).to have_http_status(:not_found)
    end
  end
end
