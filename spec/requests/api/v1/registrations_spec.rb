require "rails_helper"

RSpec.describe "Api::V1::Registrations", type: :request do
  describe "POST /api/v1/auth/sign_up" do
    let(:valid_params) do
      {
        user: {
          first_name: "newuser",
          last_name: "Example",
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    it "creates a user and a persisted account with the submitted names" do
      expect {
        post "/api/v1/auth/sign_up", params: valid_params, as: :json
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      user = User.find_by(email: "newuser@example.com")
      expect(user.first_name).to eq("newuser")
      expect(user.account).to be_persisted
      expect(user.account.last_name).to eq("Example")
      expect(JSON.parse(response.body)["user"]["display_name"]).to eq("newuser Example")
      expect(JSON.parse(response.body)["user"]).not_to have_key("user_name")
    end

    it "rejects a blank first_name" do
      post "/api/v1/auth/sign_up",
           params: valid_params.merge(user: valid_params[:user].merge(first_name: "")),
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "allows duplicate names with different emails" do
      User.create!(first_name: "newuser", last_name: "Example", email: "other@example.com", password: "password123")
      post "/api/v1/auth/sign_up", params: valid_params, as: :json
      expect(response).to have_http_status(:created)
    end

    it "rejects an existing email regardless of case without leaving an account" do
      User.create!(email: "newuser@example.com", password: "password123")
      expect {
        post "/api/v1/auth/sign_up", params: valid_params.deep_merge(user: { email: "NEWUSER@example.com" }), as: :json
      }.not_to change(Account, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "requires a last name and rolls back user and account creation" do
      expect {
        post "/api/v1/auth/sign_up", params: valid_params.deep_merge(user: { last_name: "  " }), as: :json
      }.not_to change(Account, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(User.find_by(email: "newuser@example.com")).to be_nil
    end

    it "supports accented and punctuated names" do
      post "/api/v1/auth/sign_up", params: valid_params.deep_merge(user: { first_name: "  Élodie ", last_name: " O’Connor-Smith " }), as: :json
      expect(response).to have_http_status(:created)
      expect(User.find_by!(email: "newuser@example.com").display_name).to eq("Élodie O’Connor-Smith")
    end

    it "returns subscription and billing metadata in the sign-up response" do
      Subscription.create!(name: "FREE", slug: "free", yearly_price_cents: 0,
                           monthly_price_cents: 0, currency: "AUD", is_default: true,
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

  describe "audit logging" do
    let(:valid_params) do
      {
        user: {
          first_name: "newuser",
          last_name: "Example",
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    it "writes an audit log entry for a successful sign-up" do
      post "/api/v1/auth/sign_up", params: valid_params, as: :json
      expect(response).to have_http_status(:created)

      log = Log.find_by(action: "create")
      expect(log).to be_present
      expect(log.description).to include("newuser")
      expect(log.user.email).to eq("newuser@example.com")
      expect(log.log_objects.map(&:object_type)).to eq(["User"])
      expect(log.log_objects.first.object_id).to eq(User.find_by(email: "newuser@example.com").id)
    end

    it "writes an anonymous audit log entry for a failed sign-up attempt" do
      post "/api/v1/auth/sign_up",
           params: valid_params.merge(user: valid_params[:user].merge(first_name: "")),
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      log = Log.find_by(action: "create")
      expect(log).to be_present
      expect(log.user).to be_nil
      expect(log.description).to eq("Failed sign-up attempt")
    end
  end
end
