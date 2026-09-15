require "rails_helper"

# Contract specs for Billing::Providers::Stripe's change/preview calls.
#
# They stub the Stripe gem at the class-method level and assert the exact API
# shape we depend on. This is what catches gem/API drift (e.g. stripe 19
# replacing Invoice.upcoming with Invoice.create_preview, removing the
# top-level Subscription#current_period_*, and the schedule phase
# `iterations` param) as a test failure instead of a runtime 500.
RSpec.describe "Billing::Providers::Stripe change/preview", type: :model do
  let(:adapter) { Billing::Providers::Stripe.new }

  let(:period_end) { 1.year.from_now.change(usec: 0) }
  let(:period_start) { Time.current.change(usec: 0) }

  before(:context) do
    # Force autoload + self-registration of the Stripe provider so model
    # validation (provider inclusion check) passes when writing billing prices.
    # Without this, the test database doesn't have Stripe registered and
    # SubscriptionBillingPrice.create! fails with "Provider is not included
    # in the list".
    Billing::Providers::Stripe
  end

  # Minimal double of a Stripe::Subscription as returned by retrieve().
  let(:stripe_subscription) do
    price = Struct.new(:id).new("price_trade")
    item = Struct.new(:id, :price, :quantity, :current_period_start, :current_period_end)
                 .new("si_1", price, 1, period_start.to_i, period_end.to_i)
    Struct.new(:id, :customer, :status, :items)
          .new("sub_123", "cus_123", "active", Struct.new(:data).new([item]))
  end

  # Minimal double of a Stripe::Subscription as returned by retrieve().
  let(:stripe_subscription) do
    price = Struct.new(:id).new("price_trade")
    item = Struct.new(:id, :price, :quantity, :current_period_start, :current_period_end)
                 .new("si_1", price, 1, period_start.to_i, period_end.to_i)
    Struct.new(:id, :customer, :status, :items)
          .new("sub_123", "cus_123", "active", Struct.new(:data).new([item]))
  end

  # Builds an invoice line-item double shaped like the real stripe >= 19 object,
  # where the proration flag lives on the line's parent (parent.subscription_item_details.proration).
  # The top-level `proration` attribute was removed, which is exactly why reading
  # it silently yielded nil and made the amount due today show as $0.
  def proration_line_double(amount, proration:)
    details = double("SubscriptionItemDetails", proration: proration)
    parent = double("Parent", subscription_item_details: details)
    double("Line", amount: amount, parent: parent)
  end

  # The upcoming invoice preview: a single proration line.
  let(:preview_invoice) do
    lines = double("Lines", data: [proration_line_double(8_500, proration: true)])
    Struct.new(:amount_due, :currency, :lines).new(8_500, "aud", lines)
  end

  before do
    load Rails.root.join("db/seeds/subscriptions.rb")
    allow(::Stripe::Subscription).to receive(:retrieve).with("sub_123").and_return(stripe_subscription)
    allow(::Stripe::Invoice).to receive(:create_preview).and_return(preview_invoice)
  end

  def seed_stripe_price!(slug, price_id, amount_cents)
    plan = Subscription.find_by!(slug: slug)
    SubscriptionBillingPrice.create!(
      subscription: plan, provider: "stripe", provider_price_id: price_id,
      amount_cents: amount_cents, currency: "AUD", billing_interval: "year"
    )
    plan
  end

  let(:user) do
    trade = seed_stripe_price!("trade", "price_trade", 24_000)
    seed_stripe_price!("consumer", "price_consumer", 7_00)

    u = User.create!(user_name: "roma", email: "adapter@example.com", password: "password123")
    u.user_subscriptions.create!(
      subscription: trade, started_at: Time.current, status: :active,
      billing_provider: "stripe", provider_subscription_id: "sub_123",
      current_period_start: period_start, current_period_end: period_end
    )
    u.update!(subscription: trade)
    u
  end

  before do
    allow(::Stripe::Subscription).to receive(:retrieve).with("sub_123").and_return(stripe_subscription)
    allow(::Stripe::Invoice).to receive(:create_preview).and_return(preview_invoice)
  end

  describe "#preview_change" do
    it "uses the Create Preview endpoint with subscription_details overrides" do
      adapter.preview_change(user: user, target_subscription: Subscription.find_by!(slug: "consumer"))

      expect(::Stripe::Invoice).to have_received(:create_preview).with(
        hash_including(
          customer: "cus_123",
          subscription: "sub_123",
          subscription_details: {
            items: [{ id: "si_1", price: "price_consumer", quantity: 1 }],
            proration_date: kind_of(Integer)
          },
          expand: ["lines.data.parent"]
        )
      )
    end

    it "correctly sums only proration lines for the amount due today" do
      # Mock a preview invoice with both proration and renewal lines
      # Renewal: 40000 (proration: false)
      # Proration debit: 40000 (proration: true)
      # Proration credit: -24000 (proration: true)
      # Total amount_due: 40000 + 40000 - 24000 = 56000.
      # Only the proration lines (parent.subscription_item_details.proration)
      # count towards the amount due today: 40000 - 24000 = 16000.

      mock_line_renewal = proration_line_double(400_00, proration: false)
      mock_line_debit = proration_line_double(400_00, proration: true)
      mock_line_credit = proration_line_double(-240_00, proration: true)

      mock_lines = double("Lines", data: [mock_line_renewal, mock_line_debit, mock_line_credit])
      mock_preview = double("Invoice",
        lines: mock_lines,
        amount_due: 560_00,
        currency: "aud"
      )

      allow(::Stripe::Invoice).to receive(:create_preview).and_return(mock_preview)

      distributor = seed_stripe_price!("distributor", "price_distributor", 40_000)
      result = adapter.preview_change(user: user, target_subscription: distributor)

      expect(result[:due_today_cents]).to eq(160_00)
      expect(result[:next_renewal_cents]).to eq(400_00)
    end

    it "reports nothing due today for a downgrade (scheduled, not charged)" do
      result = adapter.preview_change(
        user: user, target_subscription: Subscription.find_by!(slug: "consumer")
      )

      expect(result[:direction]).to eq("downgrade")
      # Stripe previews a credit proration, but a downgrade collects nothing now
      # — it only takes effect at the next renewal.
      expect(result[:due_today_cents]).to eq(0)
    end

    it "treats a higher-ranked target as an upgrade with the prorated amount" do
      distributor = seed_stripe_price!("distributor", "price_distributor", 40_000)

      result = adapter.preview_change(user: user, target_subscription: distributor)

      expect(result[:direction]).to eq("upgrade")
      expect(result[:due_today_cents]).to eq(8_500)
    end

    it "maps Stripe failures to Billing::Error instead of a 500" do
      allow(::Stripe::Invoice).to receive(:create_preview)
        .and_raise(::Stripe::StripeError.new("boom"))

      expect {
        adapter.preview_change(user: user, target_subscription: Subscription.find_by!(slug: "consumer"))
      }.to raise_error(Billing::Error, /boom/)
    end
  end

  describe "#change_subscription (downgrade)" do
    let(:schedule) { Struct.new(:id).new("sub_sched_1") }

    before do
      allow(::Stripe::SubscriptionSchedule).to receive(:create).and_return(schedule)
      allow(::Stripe::SubscriptionSchedule).to receive(:update)
    end

    it "bounds the current-price phase with end_date (no legacy iterations)" do
      result = adapter.change_subscription(
        user: user, target_subscription: Subscription.find_by!(slug: "consumer"), mode: :downgrade
      )

      expect(::Stripe::SubscriptionSchedule).to have_received(:create).with(from_subscription: "sub_123")
      expect(::Stripe::SubscriptionSchedule).to have_received(:update).with(
        "sub_sched_1",
        phases: [
          {
            items: [{ price: "price_trade", quantity: 1 }],
            start_date: "now",
            end_date: period_end.to_i
          },
          { items: [{ price: "price_consumer", quantity: 1 }] }
        ]
      )
      expect(result[:effective_at]).to be_within(1.second).of(period_end)
    end

    it "reuses the existing phase start_date when the subscription already has a schedule" do
      sub_with_schedule = Struct.new(:id, :customer, :status, :items, :schedule)
                                 .new("sub_123", "cus_123", "active",
                                      stripe_subscription.items, "sub_sched_1")
      allow(::Stripe::Subscription).to receive(:retrieve).with("sub_123").and_return(sub_with_schedule)

      existing = double("Schedule",
        current_phase: double("CurrentPhase", start_date: period_start.to_i))
      allow(::Stripe::SubscriptionSchedule).to receive(:retrieve)
        .with("sub_sched_1").and_return(existing)

      adapter.change_subscription(
        user: user, target_subscription: Subscription.find_by!(slug: "consumer"), mode: :downgrade
      )

      expect(::Stripe::SubscriptionSchedule).not_to have_received(:create)
      expect(::Stripe::SubscriptionSchedule).to have_received(:update).with(
        "sub_sched_1",
        phases: [
          hash_including(start_date: period_start.to_i, end_date: period_end.to_i),
          { items: [{ price: "price_consumer", quantity: 1 }] }
        ]
      )
    end

    it "maps Stripe failures to Billing::Error" do
      allow(::Stripe::SubscriptionSchedule).to receive(:update)
        .and_raise(::Stripe::StripeError.new("nope"))

      expect {
        adapter.change_subscription(
          user: user, target_subscription: Subscription.find_by!(slug: "consumer"), mode: :downgrade
        )
      }.to raise_error(Billing::Error, /nope/)
    end
  end

  describe "#change_subscription (upgrade)" do
    let(:open_invoice) do
      double("Invoice", id: "in_proration", status: "open",
                        hosted_invoice_url: "https://invoice.stripe.com/i/abc")
    end
    let(:updated_subscription) { double("Subscription", latest_invoice: open_invoice) }

    before do
      allow(::Stripe::Subscription).to receive(:update).and_return(updated_subscription)
    end

    it "bills the prorated difference immediately (always_invoice)" do
      distributor = seed_stripe_price!("distributor", "price_distributor", 40_000)

      result = adapter.change_subscription(
        user: user, target_subscription: distributor, mode: :upgrade
      )

      expect(::Stripe::Subscription).to have_received(:update).with(
        "sub_123",
        items: [{ id: "si_1", price: "price_distributor" }],
        # `create_prorations` (the default) would NOT invoice now because we keep
        # the billing anchor, silently deferring the charge to the next renewal.
        proration_behavior: "always_invoice",
        proration_date: kind_of(Integer),
        payment_behavior: "allow_incomplete",
        expand: ["latest_invoice"],
        metadata: {
          from_subscription_id: user.subscription_id,
          to_subscription_id: distributor.id,
          change_type: "upgrade"
        }
      )
      expect(result[:mode]).to eq("upgrade")
    end

    it "returns the hosted invoice URL while the charge still needs paying" do
      distributor = seed_stripe_price!("distributor", "price_distributor", 40_000)

      result = adapter.change_subscription(
        user: user, target_subscription: distributor, mode: :upgrade
      )

      expect(result[:provider_invoice_id]).to eq("in_proration")
      expect(result[:hosted_invoice_url]).to eq("https://invoice.stripe.com/i/abc")
    end

    it "does not surface a hosted invoice URL once the charge has settled" do
      paid_invoice = double("Invoice", id: "in_paid", status: "paid", hosted_invoice_url: nil)
      allow(::Stripe::Subscription).to receive(:update)
        .and_return(double("Subscription", latest_invoice: paid_invoice))
      distributor = seed_stripe_price!("distributor", "price_distributor", 40_000)

      result = adapter.change_subscription(
        user: user, target_subscription: distributor, mode: :upgrade
      )

      expect(result[:provider_invoice_id]).to eq("in_paid")
      expect(result[:hosted_invoice_url]).to be_nil
    end
  end
end