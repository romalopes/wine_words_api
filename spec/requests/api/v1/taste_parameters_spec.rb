require 'rails_helper'

# Request specs for Api::V1::TasteParametersController
#
# TasteParameter is the catalogue of sliders exposed on the React
# finder (acidity, body, tannin, sweetness, alcohol, fruit). These
# specs cover the JSON CRUD surface and the TasteParameterSerializer.
RSpec.describe "Api::V1::TasteParameters", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:wine_manager) do
    User.create!(first_name: "Manager", email: "taste-manager@example.com", password: "password123")
  end

  before do
    sign_in wine_manager
  end

  let!(:acidity) do
    TasteParameter.create!(
      slug: "acidity",
      label: "Acidity",
      label_1: "Low",
      label_2: "Medium (-)",
      label_3: "Medium",
      label_4: "Medium (+)",
      label_5: "High",
      help: "How bright, fresh, or mouth-watering the wine feels.",
    )
  end

  let!(:body) do
    TasteParameter.create!(
      slug: "body",
      label: "Body",
      label_1: "Light",
      label_2: "Medium (-)",
      label_3: "Medium",
      label_4: "Medium (+)",
      label_5: "Full",
      help: "The weight and richness of the wine on your palate.",
    )
  end

  describe "GET /api/v1/taste_parameters" do
    it "returns a successful response" do
      get "/api/v1/taste_parameters"
      expect(response).to have_http_status(:ok)
    end

    it "returns every taste parameter" do
      get "/api/v1/taste_parameters"
      parsed = JSON.parse(response.body)
      expect(parsed.length).to eq(2)
      slugs = parsed.map { |tp| tp["slug"] }
      expect(slugs).to match_array(%w[acidity body])
    end

    it "uses the TasteParameterSerializer for each row" do
      get "/api/v1/taste_parameters"
      first = JSON.parse(response.body).find { |tp| tp["slug"] == "acidity" }
      expect(first).to include(
        "slug"    => "acidity",
        "label" => "Acidity",
        "labels" => { "1" => "Low", "2" => "Medium (-)", "3" => "Medium", "4" => "Medium (+)", "5" => "High" },
        "low"   => "Low",
        "high"  => "High",
        "help"  => "How bright, fresh, or mouth-watering the wine feels.",
      )
    end
  end

  describe "GET /api/v1/taste_parameters/:id" do
    it "returns the requested parameter" do
      get "/api/v1/taste_parameters/#{acidity.slug}"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["label"]).to eq("Acidity")
    end

    it "returns 404 for a missing parameter" do
      get "/api/v1/taste_parameters/does-not-exist"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/taste_parameters" do
    let(:valid_params) do
      {
        taste_parameter: {
          slug: "tannin",
          label: "Tannin",
          label_1: "Low",
          label_2: "Medium (-)",
          label_3: "Medium",
          label_4: "Medium (+)",
          label_5: "High",
          help: "The drying texture, common in red wines.",
        },
      }
    end

    it "creates a new taste parameter and returns 201 Created" do
      expect {
        post "/api/v1/taste_parameters", params: valid_params, as: :json
      }.to change(TasteParameter, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it "persists the submitted attributes" do
      post "/api/v1/taste_parameters", params: valid_params, as: :json
      tp = TasteParameter.find_by!(slug: "tannin")
      expect(tp.label).to eq("Tannin")
      expect(tp.label_for(1)).to eq("Low")
      expect(tp.label_for(5)).to eq("High")
    end

    it "rejects a duplicate label with 422" do
      # The model has a `validates :label, uniqueness: true` rule, so
      # posting a duplicate label should produce a 422.
      post "/api/v1/taste_parameters",
            params: { taste_parameter: { slug: "tannin-2", label: acidity.label, label_1: "Low", label_2: "Medium (-)", label_3: "Medium", label_4: "Medium (+)", label_5: "High" } },
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/v1/taste_parameters/:id" do
    it "updates an existing taste parameter" do
      patch "/api/v1/taste_parameters/#{acidity.slug}",
            params: { taste_parameter: { help: "Updated help text." } },
            as: :json
      expect(response).to have_http_status(:ok)
      expect(acidity.reload.help).to eq("Updated help text.")
    end

    it "returns 404 for a missing parameter" do
      patch "/api/v1/taste_parameters/missing",
            params: { taste_parameter: { label: "x" } },
            as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/taste_parameters/:id" do
    it "destroys the taste parameter and returns 204" do
      expect {
        delete "/api/v1/taste_parameters/#{acidity.slug}"
      }.to change(TasteParameter, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "returns 404 for a missing parameter" do
      delete "/api/v1/taste_parameters/missing"
      expect(response).to have_http_status(:not_found)
    end
  end
end
