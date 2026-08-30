class Grape < ApplicationRecord
  has_many :wine_grapes, dependent: :destroy
  has_many :wines, through: :wine_grapes
  belongs_to :country, optional: true

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :color, inclusion: { in: %w[red white rosé orange], allow_blank: true }
  validates :relevance, numericality: { only_integer: true, allow_nil: true }

  scope :by_color, ->(color) { where(color: color) if color.present? }
  scope :blending, -> { where(is_blending_grape: true) }
  scope :alphabetical, -> { order(:name) }
  scope :relevance_order, -> { order(relevance: :desc) }
end
