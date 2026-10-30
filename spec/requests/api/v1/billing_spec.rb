require 'rails_helper'

RSpec.describe "Api::V1::Billing", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    User.create!(first_name: "Admin", email: "admin@example.com", password: "password123")
  end
  before { admin.roles << Role.find_or_create_by!(name: "Admin") }

  describe "GET /api/v1/billing" do
    it "returns billing information when accessed by admin" do
      sign_in admin
      get "/api/v1/billing"
      expect(response).to have_http_status(:ok)
    end

    it "denies access to unauthenticated users" do
      get "/api/v1/billing"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
