class TasteParameter < ApplicationRecord
  LABEL_LEVELS = (1..5).freeze

  has_many :wine_taste_parameters
  has_many :wines, through: :wine_taste_parameters

  has_many :wine_profile_taste_parameters, foreign_key: :taste_parameter_id
  has_many :wine_profiles, through: :wine_profile_taste_parameters, foreign_key: :taste_parameter_id

  validates :label, uniqueness: true
  validates :label_1, :label_2, :label_3, :label_4, :label_5, presence: true

  scope :sorted_by_label, -> { order(:label) }

  before_validation :generate_slug, on: :create

  def label_for(value)
    numeric_value = Integer(value, exception: false)
    return nil unless numeric_value && LABEL_LEVELS.cover?(numeric_value)

    public_send("label_#{numeric_value}")
  end

  def labels
    LABEL_LEVELS.to_h { |level| [level.to_s, public_send("label_#{level}")] }
  end

  private

  def generate_slug
    return if slug.present?
    return if label.blank?

    base = label.parameterize
    candidate = base
    suffix = 1
    while TasteParameter.where.not(id: id).exists?(slug: candidate)
      suffix += 1
      candidate = "#{base}-#{suffix}"
    end
    self.slug = candidate
  end
end
