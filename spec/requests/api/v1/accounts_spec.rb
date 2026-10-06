require "rails_helper"

# Request specs for Api::V1::AccountsController — authenticated account
# profile (personal info, address) and password change.
RSpec.describe "Api::V1::Accounts", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) do
    User.create!(first_name: "roma", email: "roma@example.com", password: "password123")
  end

  before { sign_in user }

  describe "GET /api/v1/account" do
    it "requires authentication" do
      sign_out user
      get "/api/v1/account"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the persisted account created with the user" do
      get "/api/v1/account"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).not_to have_key("user_name")
      expect(user.account).to be_persisted
      expect(body["first_name"]).to eq("roma")
      expect(body["address"]).to be_nil
    end
  end

  describe "PATCH /api/v1/account" do
    it "creates and updates the account with personal info and address" do
      country = Country.first || Country.create!(name: "Testland", code: "TL")

      patch "/api/v1/account", params: {
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
      expect(user.reload.display_name).to eq("Roma Lopes")
      account = user.account
      expect(account.first_name).to eq("Roma")
      expect(account.phone).to eq("+61 400 000 000")
      expect(account.account_address.city).to eq("Adelaide")
      expect(account.account_address.country_id).to eq(country.id)
    end

    it "allows matching names on different accounts" do
      User.create!(first_name: "Roma", last_name: "Lopes", email: "taken@example.com", password: "password123")
      patch "/api/v1/account", params: { first_name: "Roma", last_name: "Lopes" }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it "rejects blank names without changing the stored account" do
      patch "/api/v1/account", params: { first_name: " ", last_name: "Lopes" }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.first_name).to eq("roma")
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
