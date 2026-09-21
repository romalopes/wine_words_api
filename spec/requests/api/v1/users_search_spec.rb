# Request specs for GET /api/v1/users/search (admin-only user directory).
# Covers the pagination envelope (20 per page via Api::Paginatable), the
# username/email match, and the legacy plain-array response when no page param
# is given.
require "rails_helper"

RSpec.describe "Api::V1::Users search", type: :request do
  let(:admin) { User.create!(user_name: "Search Admin", email: "search-admin@example.com", password: "password123", roles: [Role.find_or_create_by!(name: "Admin")]) }

  def create_user(name, email)
    User.create!(user_name: name, email: email, password: "password123")
  end

  before do
    25.times { |i| create_user("Bulk User #{format('%02d', i)}", "bulk#{i}@example.com") }
    create_user("Wine Lover", "unique-address@yahoo.com.br")
    sign_in admin
  end

  describe "with page param" do
    it "returns the envelope with 20 items per page" do
      get "/api/v1/users/search?q=&page=1", as: :json
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["per_page"]).to eq(20)
      expect(body["items"].length).to eq(20)
      expect(body["total_pages"]).to eq(2)
      expect(body["page"]).to eq(1)
    end

    it "serves the remaining users on page 2" do
      get "/api/v1/users/search?q=&page=2", as: :json
      body = JSON.parse(response.body)
      expect(body["items"].length).to eq(User.count - 20)
      expect(body["page"]).to eq(2)
    end

    it "matches by user_name substring" do
      get "/api/v1/users/search?q=wine&page=1", as: :json
      names = JSON.parse(response.body)["items"].map { |u| u["user_name"] }
      expect(names).to include("Wine Lover")
      expect(names).not_to include("Bulk User 00")
    end

    it "matches by email substring" do
      get "/api/v1/users/search?q=unique-address&page=1", as: :json
      emails = JSON.parse(response.body)["items"].map { |u| u["email"] }
      expect(emails).to eq(["unique-address@yahoo.com.br"])
    end
  end

  describe "without page param (legacy)" do
    it "returns a plain array capped at 20" do
      get "/api/v1/users/search?q=", as: :json
      body = JSON.parse(response.body)
      expect(body).to be_an(Array)
      expect(body.length).to eq(20)
    end
  end
end
