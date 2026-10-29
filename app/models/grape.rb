class Grape < ApplicationRecord
  # Search vectors that index this record's values (see SearchVectorDependent).
  include SearchVectorDependent
  SEARCH_VECTOR_ATTRIBUTES = %w[name].freeze

  has_many :wine_grapes, dependent: :destroy
  has_many :wines, through: :wine_grapes
  has_many :producer_grapes, dependent: :destroy
  has_many :producers, through: :producer_grapes
  has_many :grape_regions, dependent: :destroy
  has_many :regions, through: :grape_regions
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

  # Find a grape by exact name (case-insensitive) or by ILIKE search on name and synonyms.
  # Returns the first matching grape or nil.
  def self.find_by_name_or_synonym(name)
    return nil if name.blank?
    # Exact match (case-insensitive)
    exact = where('lower(name) = ?', name.downcase).first
    return exact if exact
    # Fallback to ILIKE search on name and synonyms (same as used in /grapes search)
    pattern = "%#{name}%"
    where("name ILIKE ? OR array_to_string(synonyms, ',') ILIKE ?", pattern, pattern)
      .order(:name)
      .first
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

  private

  # Reviews of wines carrying this grape index its name.
  def search_reindex_targets
    { "Review" => self.class.review_ids_for_wines(wines) }
  end
end
