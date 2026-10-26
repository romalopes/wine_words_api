require "rails_helper"

RSpec.describe "Wine HTML create flow", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:producer) { Producer.create!(name: "Penfolds", slug: "penfolds") }
  let(:admin) do
    User.create!(first_name: "Admin", email: "admin@example.com", password: "password123")
  end

  def acidity
    @acidity ||= AutoAssignHelpers.make_taste_parameter("acidity", "Acidity")
  end

  def body_parameter
    @body ||= AutoAssignHelpers.make_taste_parameter("body", "Body")
  end

  before do
    admin.roles << Role.find_or_create_by!(name: "Admin")
    post "/login", params: { email: admin.email, password: "password123" }
  end

  it "creates a wine and links a closest profile, copying its taste scores" do
    profile = AutoAssignHelpers.make_profile("Pinot Noir")
    profile.wine_profile_taste_parameters.create!(taste_parameter: acidity, score: 4)
    profile.wine_profile_taste_parameters.create!(taste_parameter: body_parameter, score: 2)

    post "/wines", params: { wine: { name: "Penfolds Pinot Noir", color: "Red", producer_id: producer.id } }

    expect(response).to redirect_to(wine_path(Wine.find_by(name: "Penfolds Pinot Noir")))
    wine = Wine.find_by(name: "Penfolds Pinot Noir")
    expect(wine.wine_profile).to eq(profile)
    expect(wine.wine_taste_parameters.pluck(:score)).to eq([4, 2])
  end

  it "leaves copied taste rows intact when no taste parameters are submitted" do
    profile = AutoAssignHelpers.make_profile("Pinot Noir")
    profile.wine_profile_taste_parameters.create!(taste_parameter: acidity, score: 4)

    post "/wines", params: { wine: { name: "My New Pinot", color: "Red", producer_id: producer.id } }

    wine = Wine.find_by(name: "My New Pinot")
    expect(wine.wine_profile).to eq(profile)
    expect(wine.wine_taste_parameters.count).to eq(1)
    expect(wine.wine_taste_parameters.pluck(:score)).to eq([4])
  end

  it "leaves taste parameters unchanged when the user submits any of them" do
    profile = AutoAssignHelpers.make_profile("Pinot Noir")
    profile.wine_profile_taste_parameters.create!(taste_parameter: acidity, score: 4)

    post "/wines", params: { wine: { name: "Pinot Noir with score", color: "Red", producer_id: producer.id, wine_taste_parameters_attributes: [{ taste_parameter_id: acidity.id, score: 2 }] } }

    wine = Wine.find_by(name: "Pinot Noir with score")
    expect(wine.wine_profile).to be_nil
    expect(wine.wine_taste_parameters.pluck(:score)).to eq([2])
  end
end
