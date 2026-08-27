class Vintage < ApplicationRecord
  belongs_to :wine
  has_many :reviews, dependent: :destroy

  validates :year, presence: true, numericality: { greater_than_or_equal_to: 1900 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  accepts_nested_attributes_for :reviews, allow_destroy: true, reject_if: :all_blank

  delegate :name, to: :wine, prefix: true, allow_nil: true

  def name
    [wine&.name, year].compact.join(" ")
  end

  def slug
    "#{wine&.slug}-#{year}"
  end
end
