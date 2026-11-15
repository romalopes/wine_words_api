# A commercial quote for an approved Trade package (IDENTITY_206 Phase 10).
#
# Lifecycle: draft -> sent -> accepted/expired/cancelled. Acceptance is the
# ONLY path that generates an invoice (Trade::Invoices::GenerateFromQuote) and
# moves the package to `invoiced`. Items are frozen into a JSONB array at
# creation so later catalogue edits can never silently reprice a quote.
class WinePackageQuote < ApplicationRecord
  SERVICE_TYPES = %w[review listing review_and_listing].freeze
  STATUSES = %w[draft sent accepted expired cancelled].freeze

  belongs_to :wine_package
  belongs_to :created_by, class_name: "User"

  enum :service_type, SERVICE_TYPES.index_by(&:itself), default: :review, validate: true
  enum :status, STATUSES.index_by(&:itself), default: :draft, validate: true

  validates :items, presence: true
  validates :currency, presence: true, length: { is: 3 }
  validates :subtotal, :tax, :total,
            numericality: { greater_than_or_equal_to: 0 }
  validate :total_equals_components
  validate :one_active_quote_per_service, on: :create
  validate :items_priceable, if: :items_changed_before_send?

  scope :active, -> { where(status: %w[draft sent]) }

  # One active quote per package per service batch (Phase 10 duplicate rule).
  def one_active_quote_per_service
    clash = wine_package.wine_package_quotes.active
                        .where.not(id: id)
                        .where(service_type: service_type)
    errors.add(:base, "an active quote for this service already exists") if clash.exists?
  end

  def total_equals_components
    return if subtotal.nil? || tax.nil? || total.nil?

    errors.add(:total, "must equal subtotal + tax") unless total == subtotal + tax
  end

  # A quote may only be SENT once its items carry a price.
  def items_priceable
    return unless will_save_change_to_status? && status == "sent"

    bad = items.any? { |i| i["unit_price"].to_f <= 0 }
    errors.add(:items, "must each carry a unit price before sending") if bad
  end

  def items_changed_before_send? = true

  def accepted? = status == "accepted"
end