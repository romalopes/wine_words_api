require "rails_helper"

# Account linking: connecting and disconnecting additional sign-in providers
# for a User who is already authenticated.
#
#   GET    /api/v1/auth/identities
#   POST   /api/v1/auth/identities/:provider
#   DELETE /api/v1/auth/identities/:id
#
# The rules these specs pin down: only the owner may touch their own
# identities, an identity that belongs to somebody else is never transferred,
# and a User always keeps at least one way to sign in.
RSpec.describe "Api::V1::UserIdentities", type: :request do
  include Devise::Test::IntegrationHelpers

  def create_user(email: nil, password: "password123", user_name: nil)
    User.create!(
      user_name: user_name || "Linker #{SecureRandom.hex(3)}",
      email: email || "linker-#{SecureRandom.hex(4)}@example.com",
      password: password
    )
  end

  def claims_for(provider, uid:, email: nil, verified: true, name: "Link Person")
    Authentication::Claims.new(
      provider: provider, provider_uid: uid, email: email,
      name: name, email_verified: verified
    )
  end

  def stub_verification(provider, claims)
    allow(Authentication.verifier_for(provider)).to receive(:verify) { |_credential, nonce: nil| claims }
  end

  def body
    JSON.parse(response.body)
  end

  let!(:free_plan) do
    Subscription.find_by(slug: "free") ||
      Subscription.create!(name: "FREE", slug: "free", yearly_price_cents: 0,
                           monthly_price_cents: 0, currency: "AUD", is_default: true,
                           visible: true, active: true)
  end

  let(:user) { create_user(email: "linker@example.com", user_name: "Linker") }

  describe "GET /api/v1/auth/identities" do
    it "requires authentication" do
      get "/api/v1/auth/identities"
      expect(response).to have_http_status(:unauthorized)
    end

    it "lists the connected providers and whether a password also works" do
      user.user_identities.create!(provider: "google", provider_uid: "g-1", email: user.email)

      sign_in user
      get "/api/v1/auth/identities"

      expect(response).to have_http_status(:ok)
      expect(body["identities"].map { |i| i["provider"] }).to eq([ "google" ])
      expect(body["password_authentication"]).to be true
    end

    it "reports no password for a social-only user" do
      social_user = create_user(email: "social-only@example.com")
      social_user.update_column(:encrypted_password, "") # social-only: no usable password
      social_user.user_identities.create!(provider: "apple", provider_uid: "a-1")

      sign_in social_user
      get "/api/v1/auth/identities"
      expect(body["password_authentication"]).to be false
    end
  end

  describe "POST /api/v1/auth/identities/:provider" do
    it "requires authentication" do
      post "/api/v1/auth/identities/google", params: { credential: "stub" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "connects a new provider to the authenticated User" do
      sign_in user
      stub_verification("google", claims_for("google", uid: "g-link", email: user.email))

      expect {
        post "/api/v1/auth/identities/google", params: { credential: "stub" }, as: :json
      }.to change { user.reload.user_identities.count }.by(1)

      expect(response).to have_http_status(:created)
      expect(body["identity"]["provider"]).to eq("google")

      # Linking an identity creates no User or Account.
      expect(User.where(email: user.email).count).to eq(1)
      expect(Account.where(user: user).count).to eq(0)
    end

    it "is idempotent when the identity is already connected to this User" do
      sign_in user
      stub_verification("google", claims_for("google", uid: "g-same", email: user.email))
      post "/api/v1/auth/identities/google", params: { credential: "stub" }, as: :json
      expect(response).to have_http_status(:created)

      expect {
        post "/api/v1/auth/identities/google", params: { credential: "stub" }, as: :json
      }.not_to change { user.reload.user_identities.count }
      expect(response).to have_http_status(:created)
    end

    it "refuses to transfer an identity that already belongs to another User" do
      other = create_user(email: "owner@example.com")
      other.user_identities.create!(provider: "google", provider_uid: "g-taken")

      sign_in user
      stub_verification("google", claims_for("google", uid: "g-taken", email: user.email))

      expect {
        post "/api/v1/auth/identities/google", params: { credential: "stub" }, as: :json
      }.not_to change { user.reload.user_identities.count }

      expect(response).to have_http_status(:conflict)
      expect(body["code"]).to eq("identity_taken")
      # The identity stays exactly where it was.
      expect(other.reload.user_identities.google.count).to eq(1)
    end

    it "rejects an unsupported provider" do
      sign_in user
      post "/api/v1/auth/identities/twitter", params: { credential: "stub" }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(body["code"]).to eq("unsupported_provider")
    end

    it "audits the connection without recording the credential" do
      sign_in user
      stub_verification("microsoft", claims_for("microsoft", uid: "ms-link", email: user.email))

      post "/api/v1/auth/identities/microsoft", params: { credential: "stub" }, as: :json

      log = Log.order(:id).last
      expect(log.description).to eq("Microsoft identity connected")
      expect(log.attributes.values.compact.map(&:to_s)).not_to include("stub")
    end
  describe "DELETE /api/v1/auth/identities/:id" do
    it "requires authentication" do
      identity = user.user_identities.create!(provider: "google", provider_uid: "g-del")
      delete "/api/v1/auth/identities/#{identity.id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it "disconnects a provider when another authentication method remains" do
      identity = user.user_identities.create!(provider: "google", provider_uid: "g-del-2")

      sign_in user
      expect {
        delete "/api/v1/auth/identities/#{identity.id}"
      }.to change { user.reload.user_identities.count }.by(-1)

      expect(response).to have_http_status(:no_content)
      # The password still works.
      expect(user.reload.valid_password?("password123")).to be true
      expect(Log.order(:id).last.description).to eq("Google identity disconnected")
    end

    it "refuses to remove the User's only authentication method" do
      social_user = create_user(email: "only-social@example.com")
      social_user.update_column(:encrypted_password, "") # social-only: no usable password
      identity = social_user.user_identities.create!(provider: "apple", provider_uid: "a-only")

      sign_in social_user
      expect {
        delete "/api/v1/auth/identities/#{identity.id}"
      }.not_to change { social_user.reload.user_identities.count }

      expect(response).to have_http_status(:conflict)
      expect(body["code"]).to eq("last_authentication_method")
    end

    it "does not allow disconnecting another User's identity" do
      identity = user.user_identities.create!(provider: "google", provider_uid: "g-other-owner")
      intruder = create_user(email: "intruder@example.com")

      sign_in intruder
      delete "/api/v1/auth/identities/#{identity.id}"

      expect(response).to have_http_status(:not_found)
      expect(identity.reload).to be_persisted
    end
  end

  end
end