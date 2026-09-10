require "rails_helper"
require "devise"

RSpec.describe "Api::V1::Logs", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    user = User.create!(user_name: "Admin", email: "admin@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end

  let(:reader) do
    User.create!(user_name: "Reader", email: "reader@example.com", password: "password123")
  end

  describe "GET /api/v1/logs" do
    context "as an admin" do
      before { sign_in admin }

      it "returns 200 with a logs array" do
        get "/api/v1/logs"
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["logs"]).to be_an(Array)
      end

      it "returns at most the requested number of lines" do
        get "/api/v1/logs?lines=5"
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["logs"].length).to be <= 5
      end
    end

    context "as a non-admin user" do
      before { sign_in reader }

      it "returns 403 forbidden" do
        get "/api/v1/logs"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get "/api/v1/logs"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
