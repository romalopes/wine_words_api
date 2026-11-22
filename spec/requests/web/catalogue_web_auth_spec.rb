require "rails_helper"

# Regression: the server-rendered catalogue scaffold controllers used to expose
# unauthenticated create/update/destroy (security audit issue #23, Critical).
# Reads stay public; every mutation now requires a wine manager.
RSpec.describe "Catalogue web write authorization", type: :request do
  include Devise::Test::IntegrationHelpers

  def reader
    @reader ||= User.create!(first_name: "Reader", email: "web-reader@example.com",
                             password: "password123").tap do |u|
      u.roles << Role.find_or_create_by!(name: "Reader")
    end
  end

  def reviewer
    @reviewer ||= User.create!(first_name: "Reviewer", email: "web-reviewer@example.com",
                               password: "password123").tap do |u|
      u.roles << Role.find_or_create_by!(name: "Reviewer")
    end
  end

  # path, model class, and a dummy params hash. For blocked requests the action
  # body never runs, so the params only need the top-level key.
  # NOTE: /test_parameters has no backing model (dead scaffold) — its guard is
  # asserted separately below without a count check.
  TARGETS = [
    [ "/wine_profiles",          WineProfile,          { wine_profile: { name: "Audit Profile" } } ],
    [ "/taste_parameters",       TasteParameter,       { taste_parameter: { slug: "audit", label: "Audit" } } ],
    [ "/wine_taste_parameters",  WineTasteParameter,   { wine_taste_parameter: { score: 3 } } ]
  ].freeze

  it "blocks anonymous create on every catalogue web controller" do
    TARGETS.each do |path, model, params|
      expect { post path, params: params }.not_to change(model, :count)
      expect(response).to have_http_status(:redirect)
    end

    post "/test_parameters", params: { test_parameter: { slug: "audit", label: "Audit" } }
    expect(response).to have_http_status(:redirect)
  end

  it "blocks a signed-in non-manager (Reader) on every catalogue web controller" do
    sign_in reader
    TARGETS.each do |path, model, params|
      expect { post path, params: params }.not_to change(model, :count)
      expect(response).to have_http_status(:redirect)
    end

    post "/test_parameters", params: { test_parameter: { slug: "audit", label: "Audit" } }
    expect(response).to have_http_status(:redirect)
  end

  it "lets a wine manager create a wine profile" do
    sign_in reviewer
    expect {
      post "/wine_profiles", params: { wine_profile: { name: "Audit Profile", color: "Red" } }
    }.to change(WineProfile, :count).by(1)
    expect(response).to have_http_status(:redirect)
  end

  it "keeps the catalogue index publicly readable" do
    get "/wine_profiles"
    expect(response).to have_http_status(:ok)
  end
end
