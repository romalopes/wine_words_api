require "rails_helper"

# Request specs for Api::V1::CategoriesController#index — the category list the
# React app loads on boot. The action skips authentication and returns
# user-independent data, so the response advertises a short public cache: the
# browser reuses it instead of revalidating on every page load, and the
# s-maxage directive lets a Cloudflare Cache Rule serve the path from the edge.
RSpec.describe "Api::V1::Categories index", type: :request do
  before { Category.create!(name: "Index Cat", for_review: true) }

  it "returns the categories with a public cache header" do
    get "/api/v1/categories"

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).map { |c| c["name"] }).to include("Index Cat")
    expect(response.headers["Cache-Control"]).to include("public")
    expect(response.headers["Cache-Control"]).to include("s-maxage=60")
  end

  it "scopes the list by type" do
    get "/api/v1/categories", params: { type: "review" }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).map { |c| c["name"] }).to eq(["Index Cat"])
  end
end