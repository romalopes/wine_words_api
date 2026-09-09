require "rails_helper"

RSpec.describe BillingCustomer, type: :model do
  let(:user) { User.create!(user_name: "Roma", email: "billing-customer@example.com", password: "password123") }

  # Ensure the Stripe provider is registered before validation runs (autoloading
  # is lazy in tests, and provider inclusion is validated against the registry).
  before { Billing::Providers::Stripe }

  it "is valid with a user, provider and provider customer id" do
    customer = BillingCustomer.create!(
      user: user,
      provider: "stripe",
      provider_customer_id: "cus_123"
    )
    expect(customer).to be_persisted
  end

  it "enforces a unique provider customer id per provider" do
    BillingCustomer.create!(user: user, provider: "stripe", provider_customer_id: "cus_123")
    duplicate = BillingCustomer.new(
      user: User.create!(user_name: "Other", email: "other@example.com", password: "password123"),
      provider: "stripe",
      provider_customer_id: "cus_123"
    )
    expect(duplicate).not_to be_valid
  end

  it "enforces one provider per user" do
    BillingCustomer.create!(user: user, provider: "stripe", provider_customer_id: "cus_123")
    duplicate = BillingCustomer.new(user: user, provider: "stripe", provider_customer_id: "cus_456")
    expect(duplicate).not_to be_valid
  end
end

RSpec.describe SubscriptionBillingPrice, type: :model do
  let(:subscription) do
    load Rails.root.join("db/seeds/subscriptions.rb")
    Subscription.find_by!(slug: "consumer")
  end

  before { Billing::Providers::Stripe }

  it "links a plan to a provider price with app-level fields" do
    price = SubscriptionBillingPrice.create!(
      subscription: subscription,
      provider: "stripe",
      provider_product_id: "prod_123",
      provider_price_id: "price_123",
      billing_interval: "year",
      currency: "AUD",
      amount_cents: subscription.yearly_price_cents
    )
    expect(price.amount_cents).to eq(700)
    expect(price.billing_interval).to eq("year")
  end

  it "exposes a plan's billing price for a provider" do
    SubscriptionBillingPrice.create!(
      subscription: subscription,
      provider: "stripe",
      provider_product_id: "prod_123",
      provider_price_id: "price_123",
      billing_interval: "year",
      currency: "AUD",
      amount_cents: subscription.yearly_price_cents
    )
    found = subscription.billing_price_for(:stripe)
    expect(found.provider_price_id).to eq("price_123")
    expect(subscription.billing_price_for(:paypal)).to be_nil
  end

  it "enforces uniqueness of provider price id and of subscription+provider" do
    SubscriptionBillingPrice.create!(
      subscription: subscription,
      provider: "stripe",
      provider_price_id: "price_123",
      amount_cents: 700
    )
    dup_price = SubscriptionBillingPrice.new(
      subscription: subscription,
      provider: "stripe",
      provider_price_id: "price_321",
      billing_interval: "year",
      amount_cents: 800
    )
    expect(dup_price).not_to be_valid # same subscription+provider
  end
end

RSpec.describe BillingEvent, type: :model do
  before { Billing::Providers::Stripe }

  it "marks an event processed and is idempotent" do
    event = BillingEvent.claim(
      provider: "stripe",
      provider_event_id: "evt_123",
      event_type: "invoice.paid",
      payload: { foo: "bar" }
    )
    expect(event).to be_persisted
    expect(event.processed_at).to be_present

    # Second claim returns nil (already processed)
    expect(
      BillingEvent.claim(provider: "stripe", provider_event_id: "evt_123", event_type: "invoice.paid")
    ).to be_nil
    expect(BillingEvent.count).to eq(1)
  end

  it "enforces uniqueness of provider+event id" do
    BillingEvent.create!(provider: "stripe", provider_event_id: "evt_1", event_type: "x")
    duplicate = BillingEvent.new(provider: "stripe", provider_event_id: "evt_1", event_type: "x")
    expect(duplicate).not_to be_valid
  end
end

RSpec.describe User do
  describe "apply_subscription! with billing metadata" do
    let(:user) do
      u = User.create!(user_name: "Bil", email: "bil@example.com", password: "password123")
      u.roles << Role.find_or_create_by!(name: "Reviewer")
      u
    end

    before { load Rails.root.join("db/seeds/subscriptions.rb") }

    it "records billing_provider and provider_subscription_id" do
      consumer = Subscription.find_by!(slug: "consumer")
      user.apply_subscription!(
        consumer,
        billing_provider: "stripe",
        provider_subscription_id: "sub_stripe_1"
      )

      current = user.user_subscriptions.current.first
      expect(current.billing_provider).to eq("stripe")
      expect(current.provider_subscription_id).to eq("sub_stripe_1")
      expect(user.role_names).to include("Reader")
      expect(user.role_names).to include("Reviewer")
    end

    it "defaults to manual billing when not provided" do
      free = Subscription.find_by!(slug: "free")
      user.apply_subscription!(free)
      expect(user.user_subscriptions.current.first.billing_provider).to eq("manual")
      expect(user.user_subscriptions.current.first.provider_subscription_id).to be_nil
    end
  end
end
