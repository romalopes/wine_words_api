# A Trade invoice (IDENTITY_206 Phase 10) generated from an ACCEPTED quote.
#
# * `invoice_number` is unique at the DB level and allocated from a per-year
#   sequence (WW-2026-0001) inside the generation service, retried under a
#   unique-index race.
# * PDF rendering is attached via ActiveStorage (private bucket) by the
#   generation service.
# * Payment state is ONLY mutated by the Stripe webhook (Phase 11) through
#   Trade::Payments handlers — a client can never set `paid`.
class WinePackageInvoice < ApplicationRecord
  STATUSES = %w[draft sent paid overdue cancelled refunded].freeze

  belongs_to :wine_package
  belongs_to :wine_package_quote, optional: true

  enum :status, STATUSES.index_by(&:itself), default: :draft, validate: true

  validates :invoice_number, presence: true, uniqueness: true
  validates :currency, presence: true, length: { is: 3 }
  validates :subtotal, :tax, :total, numericality: { greater_than_or_equal_to: 0 }
  validate :total_equals_components

  scope :payable, -> { where(status: %w[sent overdue]) }
  scope :settled, -> { where(status: %w[paid refunded]) }

  def total_equals_components
    return if subtotal.nil? || tax.nil? || total.nil?

    errors.add(:total, "must equal subtotal + tax") unless total == subtotal + tax
  end

  def paid? = status == "paid"

  # Has the payment gate (Phase 12) been satisfied — either by a settled
  # invoice or an explicit Admin override recorded on the package?
  def payment_gate_satisfied?(package)
    return true if paid?
    return true if package.shipping_override_at.present?

    false
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