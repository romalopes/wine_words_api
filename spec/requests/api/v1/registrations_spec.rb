require "rails_helper"

RSpec.describe "Api::V1::Registrations", type: :request do
  describe "POST /api/v1/auth/sign_up" do
    let(:valid_params) do
      {
        user: {
          user_name: "newuser",
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    it "creates a user with the given user_name" do
      expect {
        post "/api/v1/auth/sign_up", params: valid_params, as: :json
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      user = User.find_by(email: "newuser@example.com")
      expect(user.user_name).to eq("newuser")
      expect(JSON.parse(response.body)["user"]["user_name"]).to eq("newuser")
    end

    it "rejects a blank user_name" do
      post "/api/v1/auth/sign_up",
           params: valid_params.merge(user: valid_params[:user].merge(user_name: "")),
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a duplicate user_name (case-insensitive)" do
      User.create!(user_name: "NewUser", email: "other@example.com", password: "password123")
      post "/api/v1/auth/sign_up", params: valid_params, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns subscription and billing metadata in the sign-up response" do
      Subscription.create!(name: "FREE", slug: "free", yearly_price_cents: 0,
                           monthly_price_cents: 0, currency: "USD", is_default: true,
                           visible: true, active: true)

      post "/api/v1/auth/sign_up", params: valid_params, as: :json
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      user_hash = body["user"]

      expect(user_hash["subscription"]).to be_present
      expect(user_hash["subscription"]["name"]).to eq("FREE")
      expect(user_hash).to have_key("can_manage_billing")
      expect(user_hash["can_manage_billing"]).to eq(Billing.configured?)
      expect(user_hash).to have_key("billing_provider")
      expect(user_hash).to have_key("subscription_status")
    end
  end
end
