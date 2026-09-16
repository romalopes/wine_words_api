require "rails_helper"

# Email/password sign-in — the original authentication path, which social
# sign-in is layered *on top of* rather than replacing.
#
# These specs pin down the two things that make the social providers a safe
# addition: the classic flow still works exactly as before (same payload, same
# JWT), and a User created purely through a provider never gains a password it
# does not have.
RSpec.describe "Api::V1::Sessions", type: :request do
  let!(:free_plan) do
    Subscription.find_by(slug: "free") ||
      Subscription.create!(name: "FREE", slug: "free", yearly_price_cents: 0,
                           monthly_price_cents: 0, currency: "AUD", is_default: true,
                           visible: true, active: true)
  end

  let(:user) do
    User.create!(user_name: "Session Person", email: "session@example.com",
                 password: "password123")
  end

  def sign_in_params(password)
    { user: { email: user.email, password: password } }
  end

  describe "POST /api/v1/auth/sign_in" do
    it "signs in with email and password and returns the standard session" do
      post "/api/v1/auth/sign_in", params: sign_in_params("password123"), as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)["user"]
      expect(payload["id"]).to eq(user.id)
      expect(payload["email"]).to eq("session@example.com")
      expect(payload["user_name"]).to eq("Session Person")
      expect(payload["roles"]).to include("Guest")
      expect(payload.keys).to include(
        "id", "email", "user_name", "roles", "subscription",
        "billing_provider", "can_manage_billing", "subscription_status"
      )
      # devise-jwt issued the usual token.
      expect(response.headers["Authorization"]).to be_present
    end

    it "rejects a wrong password" do
      post "/api/v1/auth/sign_in", params: sign_in_params("not-the-password"), as: :json

      expect(response).to have_http_status(:unauthorized)
      # Devise's failure app owns the invalid-credentials message.
      expect(JSON.parse(response.body)["error"]).to match(/invalid email or password/i)
      expect(response.headers["Authorization"]).to be_blank
    end

    it "rejects an unknown email" do
      post "/api/v1/auth/sign_in",
           params: { user: { email: "nobody@example.com", password: "password123" } },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    # Proves the refactor onto UserSessionPayload kept one single auth response:
    # the payload a provider returns is shaped exactly like the password one.
    it "returns the same payload shape as social sign-in" do
      post "/api/v1/auth/sign_in", params: sign_in_params("password123"), as: :json
      password_keys = JSON.parse(response.body)["user"].keys.sort

      social_user = User.create!(user_name: "Social Shape", email: "social-shape@example.com",
                                 password: "password123")
      allow(Authentication.verifier_for("google")).to receive(:verify) do
        Authentication::Claims.new(provider: "google", provider_uid: "g-shape",
                                   email: "social-shape@example.com", email_verified: true)
      end
      post "/api/v1/auth/google", params: { credential: "stub" }, as: :json
      social_keys = JSON.parse(response.body)["user"].keys.sort

      expect(social_keys).to eq(password_keys)
      expect(social_user).to be_persisted
    end

    it "does not let a social-only user sign in with a password" do
      # Built the same way Authentication::SocialLogin builds one: no password.
      social_only = User.new(user_name: "Social Only", email: "social-only-signin@example.com",
                             social_signup: true)
      social_only.save!
      social_only.user_identities.create!(provider: "google", provider_uid: "g-only")

      expect(social_only.password_authentication?).to be false

      # Neither a blank password nor a guessed one is accepted.
      [ "", "password123" ].each do |guess|
        post "/api/v1/auth/sign_in",
             params: { user: { email: social_only.email, password: guess } },
             as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/auth/sign_out" do
    it "signs the user out" do
      sign_in user
      delete "/api/v1/auth/sign_out", as: :json

      expect(response).to have_http_status(:no_content).or have_http_status(:ok)
    end
  end
end