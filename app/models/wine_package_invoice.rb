# A Trade invoice (IDENTITY_206 Phase 10) generated from an ACCEPTED quote.
#
# * `invoice_number` is unique at the DB level and allocated from a per-year
#   sequence (WW-2026-0001) inside the generation service, retried under a
#   unique-index race.
# * PDF rendering is attached via ActiveStorage (private bucket) by the
#   generation service.
# * Payment state is ONLY mutated by the Stripe webhook (Phase 11) through
#   Trade::Payments handlers — a client can never set `paid`.
# * Manual review-fee invoices (IDENTITY_214) are recorded by staff after
#   external invoice sending; they carry `payment_source = "manual"`,
#   `billable_bottle_count`, `unit_fee`, and are immutable once `sent`.
class WinePackageInvoice < ApplicationRecord
  STATUSES = %w[draft sent paid overdue cancelled refunded].freeze
  PAYMENT_SOURCES = %w[stripe manual].freeze

  belongs_to :wine_package
  belongs_to :wine_package_quote, optional: true
  belongs_to :recorded_by, class_name: "User", optional: true

  enum :status, STATUSES.index_by(&:itself), default: :draft, validate: true
  enum :payment_source, PAYMENT_SOURCES.index_by(&:itself), default: :stripe, validate: true

  validates :invoice_number, presence: true, uniqueness: true
  validates :currency, presence: true, length: { is: 3 }
  validates :subtotal, :tax, :total, numericality: { greater_than_or_equal_to: 0 }
  validates :billable_bottle_count, numericality: { only_integer: true, greater_than: 0 }, if: :manual?
  validates :unit_fee, numericality: { greater_than_or_equal_to: 0 }, if: :manual?
  validates :recorded_by, presence: true, if: -> { manual? && sent? }
  validates :recorded_at, presence: true, if: -> { manual? && sent? }
  validates :cancellation_reason, presence: true, if: -> { cancelled? }
  validate :total_equals_components
  validate :immutable_money_fields_once_sent
  validate :stripe_invoice_requires_quote

  scope :payable, -> { where(status: %w[sent overdue]) }
  scope :settled, -> { where(status: %w[paid refunded]) }
  scope :manual, -> { where(payment_source: :manual) }
  scope :stripe, -> { where(payment_source: :stripe) }

  def total_equals_components
    return if subtotal.nil? || tax.nil? || total.nil?

    errors.add(:total, "must equal subtotal + tax") unless total == subtotal + tax
  end

  def paid? = status == "paid"

  def sent? = status == "sent"

  def manual? = payment_source == "manual"

  def stripe? = payment_source == "stripe"

  # For manual invoices: overdue is derived from due_at + unpaid status.
  # Never sets the stored `overdue` enum (left for Stripe legacy path).
  def overdue_for_display?
    manual? && sent? && due_at.present? && due_at < Time.current
  end

  # Has the payment gate (Phase 12) been satisfied — either by a settled
  # invoice or an explicit Admin override recorded on the package?
  def payment_gate_satisfied?(package)
    return true if paid?
    return true if package.shipping_override_at.present?

    false
  end

  # Prevent modification of money/billing fields once invoice is sent.
  # Only status transitions (sent→paid, sent→cancelled) are allowed.
  def immutable_money_fields_once_sent
    return unless sent? && (persisted? && (subtotal_changed? || tax_changed? || total_changed? ||
        currency_changed? || billable_bottle_count_changed? || unit_fee_changed? ||
        invoice_number_changed? || issued_at_changed? || due_at_changed?))
    errors.add(:base, "Cannot modify billing fields once invoice is sent")
  end

  # Stripe-sourced invoices must have a quote; manual invoices don't.
  def stripe_invoice_requires_quote
    return unless stripe? && wine_package_quote_id.nil?
    errors.add(:wine_package_quote, "must exist for Stripe-sourced invoices")
  end

  def self.next_number
    year = Date.current.year
    prefix = "WW-#{year}-"
    last = where("invoice_number LIKE ?", "#{prefix}%")
           .order(invoice_number: :desc).first&.invoice_number
    seq = last ? last.delete_prefix(prefix).to_i + 1 : 1
    "#{prefix}#{format('%04d', seq)}"
  end
end