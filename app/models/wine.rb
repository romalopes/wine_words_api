class Wine < ApplicationRecord
  belongs_to :winery, optional: true

  has_many :wine_taste_parameters, dependent: :destroy
  has_many :taste_parameters, through: :wine_taste_parameters
  has_many :vintages, dependent: :destroy

  accepts_nested_attributes_for :vintages, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :wine_taste_parameters, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
  validates :region, presence: true
  validates :color, presence: true

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
