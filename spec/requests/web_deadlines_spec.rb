require "rails_helper"
require "devise"

# Issue #185 — the server-rendered Article/Review pages must render the new
# deadline field and badges without template errors.
RSpec.describe "Web deadline rendering", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:manager) do
    user = User.create!(first_name: "Web Manager", email: "web-manager@example.com",
                        password: "password123")
    user.roles << Role.find_or_create_by!(name: "Reviewer")
    user
  end
  let(:producer) { Producer.create!(name: "Web Deadline Producer") }
  let(:wine) { Wine.create!(name: "Web Deadline Wine", producer: producer, color: "Red") }
  let(:vintage) { Vintage.create!(wine: wine, year: 2020) }

  it "renders the article index with an overdue draft badge" do
    Article.create!(title: "Overdue draft", status: "draft", user: manager,
                    deadline: Date.current - 2)
    sign_in manager

    get "/articles"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Overdue by 2 days")
  end

  it "renders the review index with an overdue draft badge" do
    Review.create!(title: "Overdue review", score: 80, status: "draft",
                   user: manager, vintage: vintage, deadline: Date.current - 1)
    sign_in manager

    get "/reviews"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Overdue by 1 day")
  end

  it "does not show an overdue warning for a published article" do
    Article.create!(title: "Published history", status: "published", user: manager,
                    deadline: Date.current - 10)
    sign_in manager

    get "/articles"

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Overdue by 10 days")
  end

  it "renders the new article form with a deadline input" do
    sign_in manager

    get "/articles/new"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="article[deadline]"')
  end

  it "renders the new review form with a deadline input" do
    sign_in manager

    get "/reviews/new"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="review[deadline]"')
  end
end
