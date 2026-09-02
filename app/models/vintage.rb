class Vintage < ApplicationRecord
  belongs_to :wine
  has_many :reviews, dependent: :destroy

  validates :year, presence: true, numericality: { greater_than_or_equal_to: 1900 }
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Money is stored as integer cents (price_cents), but the API, web forms and
  # views speak in dollars via this virtual attribute so existing callers
  # (nested vintages_attributes, number_field :price, serializers) keep working.
  def price
    price_cents ? price_cents / 100.0 : nil
  end

  def price=(value)
    self.price_cents = value.present? ? (value.to_f * 100).round : nil
  end

  accepts_nested_attributes_for :reviews, allow_destroy: true, reject_if: :all_blank

  delegate :name, to: :wine, prefix: true, allow_nil: true

  def name
    [wine&.name, year].compact.join(" ")
  end

  def slug
    "#{wine&.slug}-#{year}"
  end
end
