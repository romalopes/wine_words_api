require "rails_helper"

# Cross-cutting guarantees of social authentication: whichever provider is used
# (or how many are connected), the User stays the canonical identity and keeps
# exactly one Account, one role set, one subscription and one Stripe customer.
#
# Only provider *verification* is stubbed; identity resolution, the linking
# endpoints, session issuance and audit logging all run for real.
RSpec.describe "Api::V1::SocialAuth integrity", type: :request do
  include Devise::Test::IntegrationHelpers

  def create_user(email: nil, password: "password123", user_name: nil, **attrs)
    User.create!(
      {
        user_name: user_name || "Integrity #{SecureRandom.hex(3)}",
        email: email || "integrity-#{SecureRandom.hex(4)}@example.com",
        password: password
      }.merge(attrs)
    )
  end

  def claims_for(provider, uid:, email: nil, verified: true, name: "Integrity Person")
    Authentication::Claims.new(
      provider: provider, provider_uid: uid, email: email,
      name: name, email_verified: verified
    )
  end

  def stub_verification(provider, claims)
    allow(Authentication.verifier_for(provider)).to receive(:verify) { |_credential, nonce: nil| claims }
  end

  # A signed-in-provider request for the given provider/identity.
  def social_sign_in(provider, uid:, email: nil, verified: true, name: "Integrity Person")
    stub_verification(provider, claims_for(provider, uid: uid, email: email,
                                          verified: verified, name: name))
    post "/api/v1/auth/#{provider}", params: { credential: "stub" }, as: :json
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

  describe "provider-independent session" do
    %w[google apple microsoft facebook].each do |provider|
      it "returns the ordinary application session for #{provider}" do
        social_sign_in(provider, uid: "#{provider}-session", email: "#{provider}-session@example.com")

        expect(response).to have_http_status(:ok)
        user = body["user"]
        # Identical payload shape to email/password sign-in.
        expect(user.keys).to include("id", "email", "user_name", "roles", "subscription")
        # The existing devise-jwt mechanism issued the token.
        expect(response.headers["Authorization"]).to be_present
        expect(User.find(user["id"]).user_identities.count).to eq(1)
      end

      it "audits a #{provider} sign-in without recording the credential" do
        social_sign_in(provider, uid: "#{provider}-audit", email: "#{provider}-audit@example.com")

        log = Log.order(:id).last
        expect(log.description).to eq("User logged in with #{UserIdentity::PROVIDER_LABELS[provider]}")
        # Credentials are never written to the audit trail.
        expect(log.attributes.values.compact.map(&:to_s)).not_to include("stub")
      end
    end
  end

  describe "duplicate User prevention" do
    # Google, Apple and Microsoft vouch for the address, so a verified match
    # links onto the existing User instead of creating a second one.
    %w[google apple microsoft].each do |provider|
      it "does not duplicate an existing email/password User on #{provider}" do
        existing = create_user(email: "shared-#{provider}@example.com", user_name: "Shared #{provider}")

        expect {
          social_sign_in(provider, uid: "#{provider}-dup", email: "shared-#{provider}@example.com")
        }.not_to change(User, :count)

        expect(body["user"]["id"]).to eq(existing.id)
        expect(existing.reload.user_identities.count).to eq(1)
        # The original email/password method still works.
        expect(existing.valid_password?("password123")).to be true
      end
    end

    it "refuses to duplicate for Facebook, which supplies no verification signal" do
      existing = create_user(email: "shared-facebook@example.com")

      expect {
        social_sign_in("facebook", uid: "facebook-dup", email: "shared-facebook@example.com",
                                  verified: false)
      }.not_to change(User, :count)

      expect(response).to have_http_status(:conflict)
      expect(body["code"]).to eq("account_exists")
      # Nothing was attached: the Facebook identity is not silently trusted.
      expect(existing.reload.user_identities).to be_empty
    end

    it "does not auto-link an Apple private relay address onto an existing User" do
      create_user(email: "relay-target@example.com")
      # A relay address proves nothing about the User's own mailbox, so it must
      # never be used to attach an identity to an existing account.
      expect {
        social_sign_in("apple", uid: "apple-relay", email: "xyz789@privaterelay.appleid.com")
      }.to change(User, :count).by(1)
    end
  end

  describe "authorization is preserved" do
    it "keeps an Admin (Super User) an Admin after social sign-in" do
      admin = create_user(email: "admin-social@example.com", user_name: "Admin Social")
      admin.roles << Role.find_or_create_by!(name: "Admin")
      expect(admin.admin?).to be true

      social_sign_in("microsoft", uid: "ms-admin", email: "admin-social@example.com")

      admin.reload
      expect(admin.admin?).to be true
      expect(admin.super_admin?).to be true
      expect(admin.role_names).to include("Admin")
      # No role was granted because of the provider used.
      expect(admin.role_names).not_to include("Reader")
    end

    it "does not grant a role because of the provider used" do
      social_sign_in("google", uid: "g-plain", email: "plain-social@example.com")

      user = User.find(body["user"]["id"])
      expect(user.role_names).to eq([ "Guest" ])
      expect(user.admin?).to be false
      expect(user.reviewer?).to be false
    end
  end

  describe "subscription is preserved" do
    let!(:trade_plan) do
      Subscription.create!(name: "Trade", slug: "trade-#{SecureRandom.hex(2)}",
                           yearly_price_cents: 10_000, monthly_price_cents: 1_000,
                           currency: "AUD", is_default: false, visible: true, active: true)
    end

    it "keeps a paid subscriber on the same plan without creating a new one" do
      user = create_user(email: "trade-social@example.com")
      user.update!(subscription: trade_plan)
      user.user_subscriptions.create!(subscription: trade_plan, status: "active",
                                      started_at: Time.current, billing_provider: "manual")

      subscription_count = Subscription.count
      user_subscription_count = UserSubscription.count

      social_sign_in("google", uid: "g-trade", email: "trade-social@example.com")

      user.reload
      expect(user.subscription).to eq(trade_plan)
      # The plan the person was already on is untouched (the FREE
      # UserSubscription is the model's own after_create hook, not social login).
      expect(user.user_subscriptions.find_by(subscription: trade_plan)).to be_present
      # Social sign-in created no subscription records at all.
      expect(Subscription.count).to eq(subscription_count)
      expect(UserSubscription.count).to eq(user_subscription_count)
    end
  end

  describe "Stripe customer is preserved" do
    it "does not create a second Stripe customer on social sign-in" do
      # Ensure the Stripe adapter is registered before validation runs
      # (autoloading is lazy in tests and provider inclusion is validated
      # against the registry — same approach as spec/models/billing_spec.rb).
      Billing::Providers::Stripe
      user = create_user(email: "stripe-social@example.com")
      customer = BillingCustomer.create!(user: user, provider: "stripe",
                                         provider_customer_id: "cus_existing_123")

      expect {
        social_sign_in("apple", uid: "apple-stripe", email: "stripe-social@example.com")
      }.not_to change(BillingCustomer, :count)

      expect(user.reload.billing_customers).to contain_exactly(customer)
      expect(user.billing_customers.find_by(provider: "stripe").provider_customer_id)
        .to eq("cus_existing_123")
    end
  end

  describe "Account is preserved" do
    it "keeps exactly one Account while all four providers are connected" do
      user = create_user(email: "multi-account@example.com", user_name: "Multi Account")
      user.create_account!(first_name: "Multi", last_name: "Account")

      %w[google apple microsoft].each do |provider|
        social_sign_in(provider, uid: "#{provider}-multi", email: "multi-account@example.com")
        expect(response).to have_http_status(:ok)
      end

      # Facebook cannot auto-link by email, so it is connected through the
      # authenticated linking endpoint (the documented route for this case).
      sign_in user
      stub_verification("facebook", claims_for("facebook", uid: "facebook-multi",
                                              email: "multi-account@example.com", verified: false))
      post "/api/v1/auth/identities/facebook", params: { credential: "stub" }, as: :json
      expect(response).to have_http_status(:created)

      expect(User.where(email: "multi-account@example.com").count).to eq(1)
      expect(user.reload.user_identities.count).to eq(4)
      expect(Account.where(user: user).count).to eq(1)
      expect(user.account.first_name).to eq("Multi")
    end
  end
end