require "rails_helper"

# Request specs for Api::V1::AccountsController — authenticated account
# profile (username, personal info, address) and password change.
RSpec.describe "Api::V1::Accounts", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) do
    User.create!(user_name: "roma", email: "roma@example.com", password: "password123")
  end

  before { sign_in user }

  describe "GET /api/v1/account" do
    it "requires authentication" do
      sign_out user
      get "/api/v1/account"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns defaults when the user has no account yet" do
      get "/api/v1/account"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["user_name"]).to eq("roma")
      expect(body["first_name"]).to be_nil
      expect(body["address"]).to be_nil
    end
  end

  describe "PATCH /api/v1/account" do
    it "creates and updates the account with personal info and address" do
      country = Country.first || Country.create!(name: "Testland", code: "TL")

      patch "/api/v1/account", params: {
        user_name: "roma_new",
        first_name: "Roma",
        last_name: "Lopes",
        phone: "+61 400 000 000",
        date_of_birth: "1990-05-01",
        address: {
          street_address: "1 Wine St",
          city: "Adelaide",
          state: "SA",
          postal_code: "5000",
          country_id: country.id
        }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(user.reload.user_name).to eq("roma_new")
      account = user.account
      expect(account.first_name).to eq("Roma")
      expect(account.phone).to eq("+61 400 000 000")
      expect(account.account_address.city).to eq("Adelaide")
      expect(account.account_address.country_id).to eq(country.id)
    end

    it "rejects a duplicate username" do
      User.create!(user_name: "taken", email: "taken@example.com", password: "password123")
      patch "/api/v1/account", params: { user_name: "TAKEN" }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"].to_json).to include("user_name")
    end
  end

  describe "PATCH /api/v1/account/password" do
    it "changes the password when the current one is correct" do
      patch "/api/v1/account/password", params: {
        current_password: "password123",
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(user.reload.valid_password?("newpassword123")).to be(true)
    end

    it "fails when the current password is wrong" do
      patch "/api/v1/account/password", params: {
        current_password: "wrongpassword",
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.valid_password?("password123")).to be(true)
    end
  end
end
