class Grape < ApplicationRecord
  has_many :wine_grapes, dependent: :destroy
  has_many :wines, through: :wine_grapes
  has_many :producer_grapes, dependent: :destroy
  has_many :producers, through: :producer_grapes
  belongs_to :country, optional: true

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: true
  validates :color, inclusion: { in: %w[red white rosé orange], allow_blank: true }
  validates :relevance, numericality: { only_integer: true, allow_nil: true }

  before_validation :generate_slug

  scope :by_color, ->(color) { where(color: color) if color.present? }
  scope :blending, -> { where(is_blending_grape: true) }
  scope :alphabetical, -> { order(:name) }
  scope :relevance_order, -> { order(relevance: :desc) }

  # Use slug instead of numeric id in URLs so form submissions resolve via find_by!(slug:)
  def to_param
    slug
  end

  private

  def generate_slug
    return if slug.present? && !name_changed?
    return if name.blank?

    # self.slug = name.to_s.parameterize
    base = name.to_s.parameterize.presence || "grape"
    candidate = base
    i = 2
    while self.class.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{i}"
      i += 1
    end
    self.slug = candidate
  end
end
