require "rails_helper"

# End-to-end social sign-in through the real controllers, routes and JWT
# machinery. Only the *provider verification* step is stubbed (the provider's
# published keys cannot be reached from a test); everything after it — identity
# resolution, User/Account/role/subscription behaviour, session issuance and
# audit logging — runs for real.
RSpec.describe "Api::V1::SocialAuth", type: :request do
  def create_user(email: nil, password: "password123", user_name: nil)
    User.create!(
      user_name: user_name || "Social User #{SecureRandom.hex(2)}",
      email: email || "social-#{SecureRandom.hex(4)}@example.com",
      password: password
    )
  end

  def claims_for(provider, uid:, email: nil, verified: true, name: "Social Person")
    Authentication::Claims.new(
      provider: provider, provider_uid: uid, email: email,
      name: name, email_verified: verified
    )
  end

  # Stubs provider verification only — the resolution rules under test run for real.
  def stub_verification(provider, claims)
    stub = ->(_credential, nonce: nil) { claims }
    allow(Authentication.verifier_for(provider)).to receive(:verify, &stub)
  end

  def auth_header
    response.headers["Authorization"]
  end

  describe "POST /api/v1/auth/google" do
    it "creates a User, an Account-less identity and returns the standard session" do
      stub_verification("google", claims_for("google", uid: "g-new", email: "New.Person@Example.com"))

      expect {
        post "/api/v1/auth/google", params: { credential: "stub" }, as: :json
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)["user"]
      user = User.find(body["id"])

      expect(user.email).to eq("new.person@example.com")
      # Same payload shape as email/password sign-in.
      expect(body.keys).to include("id", "email", "user_name", "roles", "subscription")
      # A JWT is issued by the existing devise-jwt mechanism.
      expect(auth_header).to be_present
      expect(user.user_identities.google.count).to eq(1)
      expect(user.user_identities.first.email).to eq("new.person@example.com")
    end

    it "gives a social-only user no password but a Guest role and FREE subscription" do
      # The FREE plan must exist for the existing after_create hook to attach it
      # (same setup the registrations spec uses).
      Subscription.create!(name: "FREE", slug: "free", yearly_price_cents: 0,
                           monthly_price_cents: 0, currency: "AUD", is_default: true,
                           visible: true, active: true)

      stub_verification("google", claims_for("google", uid: "g-guest", email: "guest-new@example.com"))
      post "/api/v1/auth/google", params: { credential: "stub" }, as: :json

      user = User.find(JSON.parse(response.body)["user"]["id"])
      expect(user.encrypted_password).to be_blank
      expect(user.social_only?).to be true
      # role_names is the application-level representation used in the API
      # payload and the JWT ("Guest"), unlike the enum reader on Role.
      expect(user.role_names).to include("Guest")
      expect(user.subscription).to be_present
      expect(user.subscription.name).to eq("FREE")
    end

    it "authenticates the existing User again without creating a duplicate" do
      stub_verification("google", claims_for("google", uid: "g-returning", email: "returning@example.com"))
      post "/api/v1/auth/google", params: { credential: "stub" }, as: :json
      first_id = JSON.parse(response.body)["user"]["id"]

      expect {
        post "/api/v1/auth/google", params: { credential: "stub" }, as: :json
      }.not_to change(User, :count)
      expect(JSON.parse(response.body)["user"]["id"]).to eq(first_id)
    end

    it "resolves by provider uid even when the provider stops sending an email" do
      stub_verification("google", claims_for("google", uid: "g-noemail", email: "first@example.com"))
      post "/api/v1/auth/google", params: { credential: "stub" }, as: :json
      created_id = JSON.parse(response.body)["user"]["id"]

      # Second sign-in: no email in the claims at all.
      stub_verification("google", claims_for("google", uid: "g-noemail", email: nil))
      post "/api/v1/auth/google", params: { credential: "stub" }, as: :json
      expect(JSON.parse(response.body)["user"]["id"]).to eq(created_id)
    end

    it "links onto an existing email/password User instead of duplicating them" do
      existing = create_user(email: "existing@example.com", user_name: "ExistingPerson")
      stub_verification("google", claims_for("google", uid: "g-link", email: "existing@example.com"))

      expect {
        post "/api/v1/auth/google", params: { credential: "stub" }, as: :json
      }.not_to change(User, :count)

      expect(JSON.parse(response.body)["user"]["id"]).to eq(existing.id)
      expect(existing.reload.user_identities.google.count).to eq(1)
      # Password sign-in still works.
      expect(existing.valid_password?("password123")).to be true
    end

    it "refuses to auto-link when the provider did not verify the email" do
      create_user(email: "unverified@example.com")
      stub_verification("google", claims_for("google", uid: "g-unverified", email: "unverified@example.com", verified: false))

      expect {
        post "/api/v1/auth/google", params: { credential: "stub" }, as: :json
      }.not_to change(User, :count)

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)["code"]).to eq("account_exists")
    end

    it "rejects an invalid credential without creating a user" do
      allow(Authentication.verifier_for("google")).to receive(:verify)
        .and_raise(Authentication::Error.new(
          "The sign-in credential is invalid or has expired. Please try again.",
          code: :invalid_credential, status: :unauthorized
        ))

      expect {
        post "/api/v1/auth/google", params: { credential: "bad" }, as: :json
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body["code"]).to eq("invalid_credential")
      # No token contents, provider secrets or stack traces leak to the client.
      expect(body.keys).to contain_exactly("error", "code")
    end

    it "rejects an unconfigured provider safely" do
      with_env("GOOGLE_CLIENT_ID" => nil) do
        expect {
          post "/api/v1/auth/google", params: { credential: "stub" }, as: :json
        }.not_to change(User, :count)
      end

      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body)["code"]).to eq("provider_not_configured")
    end
  end
end