require "rails_helper"
require "securerandom"
require "openssl"

# End-to-end Stripe billing lifecycle tests, exercised through the real webhook
# endpoint (POST /api/v1/webhooks/stripe) with genuinely signed payloads, the
# way Stripe delivers them. Each scenario mirrors a real Stripe event sequence.
RSpec.describe "Stripe billing lifecycle via webhooks", type: :request do
  let(:secret) { "whsec_test_secret" }
  let(:stripe_customer_id) { "cus_test_123" }
  let(:provider_sub_id) { "sub_test_123" }

  let(:user) do
    load Rails.root.join("db/seeds/subscriptions.rb")
    User.create!(user_name: "Roma", email: "stripe-lifecycle@example.com", password: "password123")
  end

  let(:consumer_price) do
    SubscriptionBillingPrice.create!(
      subscription: Subscription.find_by!(slug: "consumer"),
      provider: "stripe", provider_price_id: "price_consumer",
      amount_cents: 700, currency: "AUD", billing_interval: "year", active: true
    )
  end

  let(:trade_price) do
    SubscriptionBillingPrice.create!(
      subscription: Subscription.find_by!(slug: "trade"),
      provider: "stripe", provider_price_id: "price_trade",
      amount_cents: 24_000, currency: "AUD", billing_interval: "year", active: true
    )
  end

  before do
    @original_secret = ENV["STRIPE_WEBHOOK_SECRET"]
    ENV["STRIPE_WEBHOOK_SECRET"] = secret
    Billing::Providers::Stripe # autoload + register
    user
    consumer_price
    trade_price
  end

  after { ENV["STRIPE_WEBHOOK_SECRET"] = @original_secret }

  # ── Helpers ──────────────────────────────────────────────────────────────

  def build_event(type, object)
    {
      id: "evt_#{SecureRandom.hex(8)}",
      object: "event",
      api_version: "2026-08-26.dahlia",
      type: type,
      data: { object: object }
    }
  end

  def post_webhook(event_hash)
    payload = event_hash.to_json
    t = Time.now.to_i
    signature = OpenSSL::HMAC.hexdigest("sha256", secret, "#{t}.#{payload}")
    post "/api/v1/webhooks/stripe", params: payload, headers: {
      "Content-Type" => "application/json",
      "Stripe-Signature" => "t=#{t},v1=#{signature}"
    }
  end

  def checkout_session_object(billing_price:, sub_id:, payment_status: "paid")
    {
      "id" => "cs_test_#{SecureRandom.hex(4)}",
      "object" => "checkout.session",
      "mode" => "subscription",
      "customer" => stripe_customer_id,
      "subscription" => sub_id,
      "status" => "complete",
      "payment_status" => payment_status,
      "customer_details" => { "email" => user.email },
      "success_url" => "http://localhost:5173/subscribe?checkout=success&session_id={CHECKOUT_SESSION_ID}",
      "metadata" => {
        "subscription_id" => billing_price.subscription.id.to_s,
        "billing_price_id" => billing_price.id.to_s
      }
    }
  end

  def subscription_object(billing_price:, sub_id: provider_sub_id, status: "active")
    {
      "id" => sub_id,
      "object" => "subscription",
      "customer" => stripe_customer_id,
      "status" => status,
      "items" => { "data" => [{ "price" => { "id" => billing_price.provider_price_id } }] }
    }
  end

  def invoice_object(sub_id:, status: "paid")
    {
      "id" => "in_#{SecureRandom.hex(4)}",
      "object" => "invoice",
      "subscription" => sub_id,
      "status" => status,
      "amount_paid" => 700
    }
  end

  def current_subscription
    user.user_subscriptions.current.first
  end


  # ── ✅ Successful subscription ───────────────────────────────────────────

  describe "✅ successful subscription" do
    it "activates the paid plan from checkout.session.completed" do
      post_webhook(build_event("checkout.session.completed", checkout_session_object(billing_price: consumer_price, sub_id: provider_sub_id)))

      expect(response).to have_http_status(:ok)
      expect(current_subscription).to be_present
      expect(current_subscription.subscription).to eq(consumer_price.subscription)
      expect(current_subscription.status).to eq("active")
      expect(current_subscription.billing_provider).to eq("stripe")
      expect(current_subscription.provider_subscription_id).to eq(provider_sub_id)
    end

    it "activates from customer.subscription.created and grants the Reader role" do
      user.billing_customers.create!(provider: "stripe", provider_customer_id: stripe_customer_id)

      post_webhook(build_event("customer.subscription.created", subscription_object(billing_price: consumer_price)))

      expect(response).to have_http_status(:ok)
      expect(current_subscription.subscription).to eq(consumer_price.subscription)
      expect(user.role_names).to include("Reader")
      expect(user.role_names).not_to include("Guest")
    end
  end

  # ── ❌ Card declined ─────────────────────────────────────────────────────

  describe "❌ card declined" do
    before do
      user.billing_customers.create!(provider: "stripe", provider_customer_id: stripe_customer_id)
      user.apply_subscription!(consumer_price.subscription, billing_provider: "stripe", provider_subscription_id: provider_sub_id)
    end

    it "marks the subscription past_due on invoice.payment_failed" do
      post_webhook(build_event("invoice.payment_failed", invoice_object(sub_id: provider_sub_id)))

      expect(response).to have_http_status(:ok)
      expect(current_subscription).to be_nil
      expect(user.user_subscriptions.order(:id).last.status).to eq("past_due")
    end

    it "ignores failures for subscriptions we do not know about" do
      expect {
        post_webhook(build_event("invoice.payment_failed", invoice_object(sub_id: "sub_unknown")))
      }.not_to change { user.user_subscriptions.order(:id).last.status }
    end
  end

  # ── 🔐 3D Secure authentication ──────────────────────────────────────────

  describe "🔐 3D Secure authentication" do
    it "does not activate while payment is incomplete (authentication pending)" do
      user.billing_customers.create!(provider: "stripe", provider_customer_id: stripe_customer_id)

      post_webhook(build_event("customer.subscription.created", subscription_object(billing_price: consumer_price, status: "incomplete")))

      expect(response).to have_http_status(:ok)
      expect(user.user_subscriptions.current.where(subscription: consumer_price.subscription)).to be_empty
      expect(user.role_names).to include("Guest")
    end

    it "activates once authentication completes (incomplete -> active)" do
      user.billing_customers.create!(provider: "stripe", provider_customer_id: stripe_customer_id)

      post_webhook(build_event("customer.subscription.created", subscription_object(billing_price: consumer_price, status: "incomplete")))
      post_webhook(build_event("customer.subscription.updated", subscription_object(billing_price: consumer_price, status: "active")))

      expect(response).to have_http_status(:ok)
      expect(current_subscription).to be_present
      expect(current_subscription.subscription).to eq(consumer_price.subscription)
    end

    it "activates a 3DS-completed checkout session (payment_status paid after authentication)" do
      post_webhook(build_event("checkout.session.completed", checkout_session_object(billing_price: consumer_price, sub_id: provider_sub_id)))

      expect(response).to have_http_status(:ok)
      expect(current_subscription).to be_present
    end
  end

  # ── 🔄 Subscription renewal ──────────────────────────────────────────────

  describe "🔄 subscription renewal" do
    before do
      user.billing_customers.create!(provider: "stripe", provider_customer_id: stripe_customer_id)
      user.apply_subscription!(consumer_price.subscription, billing_provider: "stripe", provider_subscription_id: provider_sub_id)
    end

    it "keeps the subscription active on invoice.paid (renewal)" do
      expect {
        post_webhook(build_event("invoice.paid", invoice_object(sub_id: provider_sub_id)))
      }.not_to change { current_subscription&.status }

      expect(response).to have_http_status(:ok)
      expect(current_subscription).to be_present
      expect(current_subscription.provider_subscription_id).to eq(provider_sub_id)
    end

    it "stays active and does not duplicate on customer.subscription.updated" do
      post_webhook(build_event("customer.subscription.updated", subscription_object(billing_price: consumer_price)))

      expect(response).to have_http_status(:ok)
      expect(user.user_subscriptions.current.count).to eq(1)
      expect(current_subscription.status).to eq("active")
      expect(current_subscription.subscription).to eq(consumer_price.subscription)
    end

    it "processes each webhook event only once (Stripe retries are idempotent)" do
      event = build_event("customer.subscription.updated", subscription_object(billing_price: consumer_price))

      post_webhook(event)
      expect { post_webhook(event) }.not_to change(BillingEvent, :count)

      expect(response).to have_http_status(:ok)
      expect(user.user_subscriptions.current.count).to eq(1)
    end
  end

  # ── ❌ Failed renewal ────────────────────────────────────────────────────

  describe "❌ failed renewal" do
    before do
      user.billing_customers.create!(provider: "stripe", provider_customer_id: stripe_customer_id)
      user.apply_subscription!(consumer_price.subscription, billing_provider: "stripe", provider_subscription_id: provider_sub_id)
    end

    it "marks the subscription past_due on customer.subscription.updated past_due" do
      post_webhook(build_event("customer.subscription.updated", subscription_object(billing_price: consumer_price, status: "past_due")))

      expect(response).to have_http_status(:ok)
      expect(user.user_subscriptions.order(:id).last.status).to eq("past_due")
    end

    it "recovers when the retry payment succeeds" do
      post_webhook(build_event("customer.subscription.updated", subscription_object(billing_price: consumer_price, status: "past_due")))
      post_webhook(build_event("customer.subscription.updated", subscription_object(billing_price: consumer_price, status: "active")))

      expect(current_subscription).to be_present
      expect(current_subscription.status).to eq("active")
      expect(current_subscription.subscription).to eq(consumer_price.subscription)
    end
  end

  # ── 🛑 Cancellation ──────────────────────────────────────────────────────

  describe "🛑 cancellation" do
    before do
      user.billing_customers.create!(provider: "stripe", provider_customer_id: stripe_customer_id)
      user.apply_subscription!(consumer_price.subscription, billing_provider: "stripe", provider_subscription_id: provider_sub_id)
    end

    it "cancels the subscription and falls back to the FREE plan" do
      post_webhook(build_event("customer.subscription.deleted", subscription_object(billing_price: consumer_price, status: "canceled")))

      expect(response).to have_http_status(:ok)
      expect(user.user_subscriptions.current.where(subscription: consumer_price.subscription)).to be_empty

      previous = user.user_subscriptions.where(subscription: consumer_price.subscription).order(:id).last
      expect(previous.status).to eq("cancelled")
      expect(previous.ended_at).to be_present

      expect(user.reload.subscription.slug).to eq("free")
      expect(user.role_names).to include("Guest")
    end
  end


  # ── 💳 Changing payment method ───────────────────────────────────────────

  describe "💳 changing payment method" do
    before do
      user.billing_customers.create!(provider: "stripe", provider_customer_id: stripe_customer_id)
      user.apply_subscription!(consumer_price.subscription, billing_provider: "stripe", provider_subscription_id: provider_sub_id)
    end

    it "keeps the subscription intact after a payment-method change via the portal" do
      # Payment-method changes produce subscription.updated events with the
      # same plan/price and no status change.
      post_webhook(build_event("customer.subscription.updated", subscription_object(billing_price: consumer_price)))

      expect(response).to have_http_status(:ok)
      expect(user.user_subscriptions.current.count).to eq(1)
      expect(current_subscription.provider_subscription_id).to eq(provider_sub_id)
      expect(current_subscription.subscription).to eq(consumer_price.subscription)
    end

    it "opens a portal session bound to the user's Stripe customer" do
      # Test env has no BILLING_PROVIDER configured; point the generic billing
      # layer at the real Stripe adapter for this test.
      allow(Billing).to receive(:configured?).and_return(true)
      allow(Billing).to receive(:adapter).and_return(Billing::Providers::Stripe.new)

      portal_session = Struct.new(:url).new("https://billing.stripe.com/portal_test")
      allow(::Stripe::BillingPortal::Session).to receive(:create).and_return(portal_session)

      result = Billing::Portal.create(user: user)

      expect(result[:url]).to eq("https://billing.stripe.com/portal_test")
      expect(::Stripe::BillingPortal::Session).to have_received(:create) do |args|
        expect(args[:customer]).to eq(stripe_customer_id)
        expect(args[:return_url]).to be_present
      end
    end
  end

  # ── 🔁 Upgrading / downgrading subscription ──────────────────────────────

  describe "🔁 upgrading / downgrading subscription" do
    before do
      user.billing_customers.create!(provider: "stripe", provider_customer_id: stripe_customer_id)
      user.apply_subscription!(consumer_price.subscription, billing_provider: "stripe", provider_subscription_id: provider_sub_id)
    end

    it "upgrades the plan when the subscription switches to a higher price" do
      post_webhook(build_event("customer.subscription.updated", subscription_object(billing_price: trade_price)))

      expect(response).to have_http_status(:ok)
      expect(user.user_subscriptions.current.count).to eq(1)
      expect(current_subscription.subscription).to eq(trade_price.subscription)
      expect(user.role_names).to include("Reader")
    end

    it "rejects downgrade attempts and keeps the higher-priced plan" do
      post_webhook(build_event("customer.subscription.updated", subscription_object(billing_price: trade_price)))
      post_webhook(build_event("customer.subscription.updated", subscription_object(billing_price: consumer_price)))

      expect(user.user_subscriptions.current.count).to eq(1)
      expect(current_subscription.subscription).to eq(trade_price.subscription)
    end
  end

  # ── Signature / adapter sanity ───────────────────────────────────────────

  describe "webhook authenticity" do
    it "rejects events signed with the wrong secret" do
      payload = build_event("checkout.session.completed", checkout_session_object(billing_price: consumer_price, sub_id: provider_sub_id)).to_json
      t = Time.now.to_i
      bad_sig = OpenSSL::HMAC.hexdigest("sha256", "whsec_wrong", "#{t}.#{payload}")

      post "/api/v1/webhooks/stripe", params: payload, headers: {
        "Content-Type" => "application/json",
        "Stripe-Signature" => "t=#{t},v1=#{bad_sig}"
      }

      expect(response).to have_http_status(:bad_request)
      expect(user.user_subscriptions.current.where(subscription: consumer_price.subscription)).to be_empty
    end

    it "maps Stripe subscription statuses to the app vocabulary" do
      adapter = Billing::Providers::Stripe.new
      expect(adapter.map_status("active")).to eq("active")
      expect(adapter.map_status("trialing")).to eq("active")
      expect(adapter.map_status("past_due")).to eq("past_due")
      expect(adapter.map_status("unpaid")).to eq("past_due")
      expect(adapter.map_status("incomplete")).to eq("past_due")
      expect(adapter.map_status("canceled")).to eq("cancelled")
      expect(adapter.map_status("paused")).to eq("paused")
      expect(adapter.map_status("whatever")).to eq("expired")
    end
  end
end

