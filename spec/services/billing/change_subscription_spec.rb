require "rails_helper"

# A minimal in-memory provider implementing the change-subscription contract so
# we can test Billing::ChangeSubscription without touching Stripe. It records
# the last operation for assertions.
class ChangeProvider
  attr_reader :last_op, :preview_calls

  def initialize
    @preview_calls = 0
  end

  def provider_key
    :stripe
  end

  def preview_change(user:, target_subscription:)
    @preview_calls += 1
    direction = target_subscription.higher_rank_than?(user.subscription) ? "upgrade" : "downgrade"
    due = direction == "upgrade" ? 8_500 : 0
    {
      direction: direction,
      due_today_cents: due,
      currency: "AUD",
      next_renewal_cents: target_subscription.yearly_price_cents,
      next_renewal_at: 1.year.from_now,
      current_period_end: 1.year.from_now,
      provider_subscription_id: "sub_123"
    }
  end

  def change_subscription(user:, target_subscription:, mode:)
    @last_op = { mode: mode, to: target_subscription }
    if mode == :upgrade
      {
        mode: "upgrade", provider_subscription_id: "sub_123",
        provider_invoice_id: "in_1",
        hosted_invoice_url: "https://invoice.stripe.com/i/1"
      }
    else
      { mode: "downgrade", provider_subscription_id: "sub_123", effective_at: 1.year.from_now }
    end
  end
end

RSpec.describe "Billing::ChangeSubscription" do
  let(:provider) { ChangeProvider.new }

  before do
    load Rails.root.join("db/seeds/subscriptions.rb")
    allow(Billing).to receive(:configured?).and_return(true)
    allow(Billing).to receive(:adapter).and_return(provider)
    Billing::Providers.register(ChangeProvider)
  end

  let(:consumer) { Subscription.find_by!(slug: "consumer") }
  let(:trade) { Subscription.find_by!(slug: "trade") }

  def activate(user, plan, provider_sub_id)
    user.user_subscriptions.current.update_all(status: :cancelled, ended_at: Time.current)
    user.update!(subscription: plan)
    user.user_subscriptions.create!(
      subscription: plan, started_at: Time.current,
      status: :active, billing_provider: "stripe",
      provider_subscription_id: provider_sub_id
    )
    user.reload
  end

  let(:user) do
    u = User.create!(user_name: "roma", email: "change@example.com", password: "password123")
    u.billing_customers.create!(provider: "stripe", provider_customer_id: "cus_123")
    activate(u, consumer, "sub_123")
  end

  describe ".preview" do
    it "returns an upgrade preview with the prorated amount due" do
      preview = Billing::ChangeSubscription.preview(user: user, target_subscription: trade)
      expect(preview[:direction]).to eq("upgrade")
      expect(preview[:due_today][:amount_cents]).to eq(8_500)
      expect(preview[:due_today][:currency]).to eq("AUD")
      expect(preview[:target][:id]).to eq(trade.id)
      expect(preview[:current][:id]).to eq(consumer.id)
    end

    it "returns a downgrade preview with $0 due today" do
      downgrade_user = activate(user, trade, "sub_trade")
      preview = Billing::ChangeSubscription.preview(user: downgrade_user, target_subscription: consumer)
      expect(preview[:direction]).to eq("downgrade")
      expect(preview[:due_today][:amount_cents]).to eq(0)
    end

    it "rejects the same plan" do
      expect {
        Billing::ChangeSubscription.preview(user: user, target_subscription: consumer)
      }.to raise_error(Billing::Error, /already on this plan/i)
    end

    it "rejects a free target plan" do
      expect {
        Billing::ChangeSubscription.preview(user: user, target_subscription: Subscription.find_by!(slug: "free"))
      }.to raise_error(Billing::Error, /Target plan is not available/i)
    end
  end

  describe ".confirm" do
    it "creates a pending upgrade and calls the provider" do
      result = Billing::ChangeSubscription.confirm(
        user: user, target_subscription: trade, idempotency_key: "key-1"
      )
      expect(result[:status]).to eq("pending")
      expect(provider.last_op[:mode]).to eq(:upgrade)
      # The Stripe invoice raised for the proration is surfaced so the UI can
      # send the customer to it when the card needs authentication (3DS/SCA).
      expect(result[:provider_invoice_id]).to eq("in_1")
      expect(result[:hosted_invoice_url]).to eq("https://invoice.stripe.com/i/1")
      change = user.subscription_changes.first
      expect(change.change_type).to eq("upgrade")
      expect(change.status).to eq("pending")
    end

    it "syncs the local subscription immediately when no hosted invoice URL is returned" do
      # Simulate a provider that processes the charge immediately (no 3DS/SCA).
      class ImmediateChangeProvider < ChangeProvider
        def change_subscription(user:, target_subscription:, mode:)
          super.merge(hosted_invoice_url: nil)
        end
      end

      immediate_provider = ImmediateChangeProvider.new
      allow(Billing).to receive(:adapter).and_return(immediate_provider)

      result = Billing::ChangeSubscription.confirm(
        user: user, target_subscription: trade, idempotency_key: "key-immediate"
      )
      expect(result[:status]).to eq("succeeded")
      expect(result[:hosted_invoice_url]).to be_nil
      change = user.subscription_changes.first
      expect(change.change_type).to eq("upgrade")
      expect(change.status).to eq("succeeded")
      # Local subscription is synced proactively.
      expect(user.reload.subscription).to eq(trade)
    end

    it "schedules a downgrade effective at the next renewal (no charge)" do
      downgrade_user = activate(user, trade, "sub_trade")
      result = Billing::ChangeSubscription.confirm(
        user: downgrade_user, target_subscription: consumer, idempotency_key: "key-d"
      )
      expect(result[:status]).to eq("scheduled")
      expect(result[:effective_at]).to be_present
      change = downgrade_user.subscription_changes.first
      expect(change.change_type).to eq("downgrade")
      expect(change.status).to eq("scheduled")
    end

    it "is idempotent per idempotency_key" do
      first = Billing::ChangeSubscription.confirm(
        user: user, target_subscription: trade, idempotency_key: "key-1"
      )
      second = Billing::ChangeSubscription.confirm(
        user: user, target_subscription: trade, idempotency_key: "key-1"
      )
      expect(second[:already_requested]).to be true
      expect(second[:subscription_change_id]).to eq(first[:subscription_change_id])
      expect(user.subscription_changes.count).to eq(1)
    end
  end
end