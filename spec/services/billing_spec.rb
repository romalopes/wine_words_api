require "rails_helper"

# A minimal in-memory provider adapter used to test the generic billing layer
# without touching Stripe. It records the last call so we can assert on it.
class FakeBillingProvider
  attr_reader :last_checkout, :last_portal, :last_customer

  def provider_key
    :stripe
  end

  def initialize
    @customers = {}
  end

  def ensure_customer(user)
    @last_customer = user
    @customers[user.id] ||= { id: "fake_cus_#{user.id}", email: user.email }
  end

  def find_customer_by_email(_email)
    nil
  end

  def create_checkout_session(user:, subscription:, billing_price:, success_url:, cancel_url:)
    @last_checkout = {
      user: user, subscription: subscription, billing_price: billing_price,
      success_url: success_url, cancel_url: cancel_url
    }
    { url: "https://checkout.example.com/fake_session", session_id: "fake_sess_1" }
  end

  def create_portal_session(user:, return_url:)
    @last_portal = { user: user, return_url: return_url }
    { url: "https://portal.example.com/fake_portal" }
  end

  def map_status(_stripe_status)
    "active"
  end
end

RSpec.describe "Billing layer" do
  let(:provider) { FakeBillingProvider.new }

  before do
    allow(Billing).to receive(:configured?).and_return(true)
    allow(Billing).to receive(:adapter).and_return(provider)
    # Register the fake provider so registry-based provider validation passes
    # (the fake adapter reports provider_key :stripe).
    Billing::Providers.register(FakeBillingProvider)
  end

  describe "Billing::Customer.find_or_create" do
    let(:user) { User.create!(name: "Roma", email: "billing@example.com", password: "password123") }

    it "creates a billing customer on first call" do
      customer = Billing::Customer.ensure!(user)
      expect(customer).to be_a(BillingCustomer)
      expect(customer.provider).to eq("stripe")
      expect(customer.provider_customer_id).to start_with("fake_cus_")
    end

    it "returns the existing customer on subsequent calls" do
      first = Billing::Customer.ensure!(user)
      second = Billing::Customer.ensure!(user)
      expect(first.id).to eq(second.id)
    end
  end

  describe "Billing::Checkout.create" do
    let(:user) { User.create!(name: "Roma", email: "checkout@example.com", password: "password123") }
    let(:subscription) do
      load Rails.root.join("db/seeds/subscriptions.rb")
      Subscription.find_by!(slug: "consumer")
    end

    before do
      SubscriptionBillingPrice.create!(
        subscription: subscription,
        provider: "stripe",
        provider_price_id: "price_123",
        amount_cents: subscription.yearly_price_cents,
        currency: "AUD",
        billing_interval: "year"
      )
    end

    it "creates a checkout session for a paid plan" do
      result = Billing::Checkout.create(user: user, subscription: subscription)
      expect(result[:url]).to include("checkout.example.com")
      expect(provider.last_checkout[:user]).to eq(user)
    end

    it "rejects a free plan" do
      free = Subscription.find_by!(slug: "free")
      expect {
        Billing::Checkout.create(user: user, subscription: free)
      }.to raise_error(Billing::Error, /not available for online purchase/i)
    end

    it "rejects a plan without an active strippable price" do
      # Use a different plan that has no billing price at all.
      trade = Subscription.find_by!(slug: "trade")
      expect {
        Billing::Checkout.create(user: user, subscription: trade)
      }.to raise_error(Billing::Error, /not available for online purchase/i)
    end
  end

  describe "Billing::Portal.create" do
    let(:user) { User.create!(name: "Roma", email: "portal@example.com", password: "password123") }

    it "creates a portal session" do
      Billing::Customer.ensure!(user)
      result = Billing::Portal.create(user: user)
      expect(result[:url]).to include("portal.example.com")
    end

    it "returns nil when the user has no billing customer" do
      result = Billing::Portal.create(user: user)
      expect(result).to be_nil
    end
  end

  describe "Billing::Subscription.activate_from_checkout" do
    let(:user) do
      u = User.create!(name: "Roma", email: "sub@example.com", password: "password123")
      u.roles << Role.find_or_create_by!(name: "Reviewer")
      u
    end
    let(:subscription) do
      load Rails.root.join("db/seeds/subscriptions.rb")
      Subscription.find_by!(slug: "consumer")
    end

    it "activates a paid subscription and preserves privileged roles" do
      Billing::Subscription.apply(
        user: user,
        subscription: subscription,
        billing_provider: "stripe",
        provider_subscription_id: "sub_fake_1"
      )
      current = user.user_subscriptions.current.first
      expect(current).to be_present
      expect(current.billing_provider).to eq("stripe")
      expect(current.provider_subscription_id).to eq("sub_fake_1")
      expect(user.role_names).to include("Reader")
      expect(user.role_names).to include("Reviewer")
    end
  end
end