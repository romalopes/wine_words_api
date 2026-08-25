class Wine < ApplicationRecord
  belongs_to :producer, optional: true
  has_many_attached :images

  has_many :wine_taste_parameters, dependent: :destroy
  has_many :taste_parameters, through: :wine_taste_parameters
  has_many :vintages, dependent: :destroy

  accepts_nested_attributes_for :vintages, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :wine_taste_parameters, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
  validates :region, presence: true
  validates :color, presence: true

  def self.colors
    %w[Red White Rosé Sparkling Dessert].freeze
  end

  # Use slug instead of numeric id in URLs so form submissions resolve via find_by!(slug:)
  def to_param
    slug
  end

  before_validation :generate_slug, on: :create

  private

  def generate_slug
    return if slug.present?
    return if name.blank?

    base = name.parameterize
    candidate = base
    suffix = 1
    while Wine.where.not(id: id).exists?(slug: candidate)
      suffix += 1
      candidate = "#{base}-#{suffix}"
    end
    self.slug = candidate
  end
end
