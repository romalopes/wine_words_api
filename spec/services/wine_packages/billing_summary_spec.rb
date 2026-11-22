require "rails_helper"

# Unit specs for WinePackages::BillingSummary (IDENTITY_214 Phase 8 — aggregate
# tests for the multiple-invoice flow).
RSpec.describe WinePackages::BillingSummary do
  let(:admin) do
    user = User.create!(first_name: "BSAdmin", email: "bs-admin@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end

  let(:producer_user) do
    User.create!(first_name: "BSProducer", email: "bs-producer@example.com", password: "password123")
  end

  let(:producer) do
    Producer.create!(name: "BS Producer", slug: "bs-producer")
  end

  let(:package) do
    ProducerMembership.create!(user: producer_user, producer: producer, membership_type: "owner")
    WinePackage.create!(
      producer: producer,
      status: "editorial_pending",
      source: "trade_submission",
      submitter: producer_user,
      contact_snapshot: {
        "company_name" => "BS Co",
        "contact_name" => "BS Owner",
        "email" => "bs@example.com"
      },
      wine_package_items_attributes: [
        { proposed_wine_name: "BS Wine 1", proposed_vintage_year: 2023, quantity: 3 },
        { proposed_wine_name: "BS Wine 2", proposed_vintage_year: 2022, quantity: 2 }
      ]
    )
  end

  subject(:summary) { described_class.new(package) }

  describe "#bottles_submitted" do
    it "returns the submitted bottle count from items" do
      expect(summary.bottles_submitted).to eq(5)
    end
  end

  describe "#billable_to_date" do
    it "returns zero before confirmation" do
      expect(summary.billable_to_date).to eq(0)
    end

    it "returns the confirmed count" do
      package.confirm_billable_quantity!(4, by: admin)
      expect(summary.billable_to_date).to eq(4)
    end
  end

  describe "#billable_uninvoiced" do
    before { package.confirm_billable_quantity!(5, by: admin) }

    it "equals billable_to_date when no invoices exist" do
      expect(summary.billable_uninvoiced).to eq(5)
    end

    it "is reduced by a sent invoice" do
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 100, tax: 0, total: 100,
        status: :sent, issued_at: Time.current, due_at: 30.days.from_now,
        payment_source: :manual, billable_bottle_count: 2, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      expect(summary.billable_uninvoiced).to eq(3)
    end

    it "is reduced by a paid invoice" do
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 100, tax: 0, total: 100,
        status: :paid, issued_at: Time.current, due_at: 30.days.from_now,
        paid_at: Time.current,
        payment_source: :manual, billable_bottle_count: 2, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      expect(summary.billable_uninvoiced).to eq(3)
    end

    it "is not reduced by a cancelled invoice (bottles released)" do
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 100, tax: 0, total: 100,
        status: :cancelled, issued_at: Time.current, due_at: 30.days.from_now,
        cancellation_reason: "Duplicate",
        payment_source: :manual, billable_bottle_count: 2, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      expect(summary.billable_uninvoiced).to eq(5)
    end

    it "never goes negative" do
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 250, tax: 0, total: 250,
        status: :sent, issued_at: Time.current, due_at: 30.days.from_now,
        payment_source: :manual, billable_bottle_count: 5, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      expect(summary.billable_uninvoiced).to eq(0)
    end
  end


  describe "#total_invoiced / #total_paid / #total_cancelled" do
    before { package.confirm_billable_quantity!(5, by: admin) }

    it "are zero before any invoices" do
      expect(summary.total_invoiced).to eq(0)
      expect(summary.total_paid).to eq(0)
      expect(summary.total_cancelled).to eq(0)
    end

    it "reflects sent, paid, and cancelled invoices" do
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 100, tax: 0, total: 100,
        status: :sent, issued_at: Time.current, due_at: 30.days.from_now,
        payment_source: :manual, billable_bottle_count: 2, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 150, tax: 0, total: 150,
        status: :paid, issued_at: Time.current, due_at: 30.days.from_now,
        paid_at: Time.current,
        payment_source: :manual, billable_bottle_count: 3, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 50, tax: 0, total: 50,
        status: :cancelled, issued_at: Time.current, due_at: 30.days.from_now,
        cancellation_reason: "Error",
        payment_source: :manual, billable_bottle_count: 1, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )

      expect(summary.total_invoiced).to eq(300) # 100 + 150 + 50 cancelled
      expect(summary.total_paid).to eq(150)
      expect(summary.total_cancelled).to eq(50)
    end
  end


  describe "#outstanding" do
    before { package.confirm_billable_quantity!(5, by: admin) }

    it "is zero with no sent invoices" do
      expect(summary.outstanding).to eq(0)
    end

    it "is the sum of sent (unpaid) invoice totals" do
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 100, tax: 0, total: 100,
        status: :sent, issued_at: Time.current, due_at: 30.days.from_now,
        payment_source: :manual, billable_bottle_count: 2, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 150, tax: 0, total: 150,
        status: :paid, issued_at: Time.current, due_at: 30.days.from_now,
        paid_at: Time.current,
        payment_source: :manual, billable_bottle_count: 3, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      expect(summary.outstanding).to eq(100)
    end
  end


  describe "#payment_state" do
    before { package.confirm_billable_quantity!(5, by: admin) }

    it "is :not_invoiced with no active invoices" do
      expect(summary.payment_state).to eq(:not_invoiced)
    end

    it "is :invoiced when a sent invoice is unpaid" do
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 100, tax: 0, total: 100,
        status: :sent, issued_at: Time.current, due_at: 30.days.from_now,
        payment_source: :manual, billable_bottle_count: 2, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      expect(summary.payment_state).to eq(:invoiced)
    end

    it "is :partially_paid when one invoice paid and another sent" do
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 100, tax: 0, total: 100,
        status: :paid, issued_at: Time.current, due_at: 30.days.from_now,
        paid_at: Time.current,
        payment_source: :manual, billable_bottle_count: 2, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 150, tax: 0, total: 150,
        status: :sent, issued_at: Time.current, due_at: 30.days.from_now,
        payment_source: :manual, billable_bottle_count: 3, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      expect(summary.payment_state).to eq(:partially_paid)
    end

      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 250, tax: 0, total: 250,
        status: :paid, issued_at: Time.current, due_at: 30.days.from_now,
        paid_at: Time.current,
        payment_source: :manual, billable_bottle_count: 5, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      expect(summary.payment_state).to eq(:settled)
    end

    it "is :settled when only cancelled invoices exist" do
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 100, tax: 0, total: 100,
        status: :cancelled, issued_at: Time.current, due_at: 30.days.from_now,
        cancellation_reason: "Duplicate",
        payment_source: :manual, billable_bottle_count: 2, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      expect(summary.payment_state).to eq(:settled)
    end
  end


  describe "#overdue?" do
    before { package.confirm_billable_quantity!(5, by: admin) }

    it "is false with no sent invoices" do
      expect(summary.overdue?).to be false
    end

    it "is false when the sent invoice is not yet due" do
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 100, tax: 0, total: 100,
        status: :sent, issued_at: Time.current, due_at: 30.days.from_now,
        payment_source: :manual, billable_bottle_count: 2, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      expect(summary.overdue?).to be false
    end

    it "is true when the sent invoice is past due" do
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 100, tax: 0, total: 100,
        status: :sent, issued_at: Time.current, due_at: 1.day.ago,
        payment_source: :manual, billable_bottle_count: 2, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      expect(summary.overdue?).to be true
    end

    it "is false when the overdue invoice is paid" do
      package.wine_package_invoices.create!(
        wine_package_quote: nil,
        invoice_number: WinePackageInvoice.next_number,
        currency: "AUD", items: [], subtotal: 100, tax: 0, total: 100,
        status: :paid, issued_at: Time.current, due_at: 1.day.ago,
        paid_at: Time.current,
        payment_source: :manual, billable_bottle_count: 2, unit_fee: 50.0,
        recorded_by: admin, recorded_at: Time.current
      )
      expect(summary.overdue?).to be false
    end
  end

  describe "#to_h" do
    before { package.confirm_billable_quantity!(5, by: admin) }

    it "returns all expected keys with 2-dp money strings" do
      hash = summary.to_h
      expect(hash).to include(
        bottles_submitted: 5,
        billable_to_date: 5,
        billable_uninvoiced: 5,
        total_invoiced: "0.00",
        total_paid: "0.00",
        total_cancelled: "0.00",
        outstanding: "0.00",
        payment_state: "not_invoiced",
        overdue: false
      )
      expect(hash[:invoices]).to eq([])
    end
  end
end

