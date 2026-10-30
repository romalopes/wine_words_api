require 'rails_helper'

# Request specs for Api::V1::UsersController
# Exercises the JSON endpoints for user account management.
RSpec.describe "Api::V1::Users", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    User.create!(first_name: "Admin", email: "admin@example.com", password: "password123")
  end
  before { admin.roles << Role.find_or_create_by!(name: "Admin") }

  describe "GET /api/v1/users" do
    it "returns a list of users when accessed by admin" do
      sign_in admin
      get "/api/v1/users"
      expect(response).to have_http_status(:ok)
    end

    it "denies access to unauthenticated users" do
      get "/api/v1/users"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/users/:id" do
    it "returns a specific user when accessed by admin" do
      sign_in admin
      get "/api/v1/users/#{admin.id}"
      expect(response).to have_http_status(:ok)
    end
  end
end