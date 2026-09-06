class Wine < ApplicationRecord
  belongs_to :producer
  belongs_to :category, optional: true
  has_many_attached :images

  has_many :wine_taste_parameters, dependent: :destroy
  has_many :taste_parameters, through: :wine_taste_parameters
  has_many :vintages, dependent: :destroy
  has_many :wine_grapes, dependent: :destroy
  has_many :grapes, through: :wine_grapes
  has_many :wine_regions, dependent: :destroy
  has_many :regions, through: :wine_regions, source: :region
  has_many :wine_categories, dependent: :destroy
  has_many :categories, through: :wine_categories

  accepts_nested_attributes_for :vintages, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :wine_taste_parameters, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
  validates :color, presence: true
  # Closure must be one of the known options — a blank value is rejected
  # (use the model default instead). Mirrors the colour requirement.
  validates :closure, inclusion: { in: ->(_) { CLOSURES } }
  validates :alcohol_percentage, presence: true
  # Volume must be one of the known bottle sizes. A blank value is
  # rejected — a new wine defaults to DEFAULT_VOLUME (750) via the
  # after_initialize callback below, so the field is never empty.
  validates :volume_ml, inclusion: { in: ->(_) { Wine.volume_values } }

  after_initialize :set_defaults, if: :new_record?

  before_validation :generate_slug, on: :create

  COLORS = %w[Red White Rosé Dessert].freeze
  DEFAULT_COLOR = "White"

  CLOSURES = [
    "Cork",
    "Screw cap",
    "Diam",
    "Crownseal",
    "Synthetic",
    "Glass Stopper",
    "Nomacorc PlantCorc",
    "Vino-Lok",
    "Agglomerate"
  ].freeze
  DEFAULT_CLOSURE = "Cork"
  DEFAULT_ALCOHOL_PERCENTAGE = 13.5

  # Allowed bottle volumes. The integer key is stored in the `volume_ml`
  # column (kept integer); the string value is the human label.
  # 187ml bottles are nominally 187.5ml (a champagne split) but rounded
  # down to 187 so the column stays an integer.
  VOLUMES = {
    187 => "187.5 ml",
    250 => "250 ml",
    375 => "375 ml",
    500 => "500 ml",
    750 => "750 ml",
    1000 => "1 L",
    1500 => "1.5 L",
    3000 => "3 L",
    5000 => "5 L",
    6000 => "6 L",
    9000 => "9 L",
    12000 => "12 L",
  }.freeze

  DEFAULT_VOLUME = 750

  # Slugs of the taste parameters filterable via advanced search.
  TASTE_PARAMETER_FILTER_SLUGS = %w[
    acidity alcohol-warmth body fruit-intensity sweetness tannin
  ].freeze

  def self.colors
    COLORS
  end

  def self.closures
    CLOSURES
  end

  def self.volumes
    VOLUMES
  end

  def self.volume_values
    VOLUMES.keys
  end

  # Friendly label for the stored integer ml value (nil-safe).
  def volume_label
    return nil if volume_ml.blank?
    self.class::VOLUMES[volume_ml] || "#{volume_ml}ml"
  end

  # Advanced, optimised search used by GET /api/v1/wines/advanced_search.
  #
  # Every filter is optional; blank/missing keys are simply ignored. The
  # relation is composed lazily with EXISTS subqueries (rather than joins) so
  # that:
  #   - no wine row is ever duplicated (no DISTINCT needed),
  #   - each filter is an independent, skippable predicate,
  #   - the database can use the per-table indexes (wines.name trgm,
  #     vintages.wine_id, reviews.vintage_id, wine_regions.wine_id, ...).
  #
  # Review filters (score / published_at / drink window) apply to the reviews
  # of the most recent vintage of the wine that actually has reviews, via one
  # correlated subquery — no per-wine Ruby loops.
  def self.advanced_search(filters)
    scope = all
    f = filters || {}

    if f[:name].present?
      scope = scope.where("wines.name ILIKE ?", "%#{f[:name]}%")
    end

    if f[:producer_name].present?
      scope = scope.joins(:producer)
                   .where("producers.name ILIKE ?", "%#{f[:producer_name]}%")
    end

    scope = scope.where(color: f[:color]) if f[:color].present?
    scope = scope.where(closure: f[:closure]) if f[:closure].present?
    scope = scope.where(sparkling: f[:sparkling]) unless f[:sparkling].nil?
    scope = scope.where(fortified: f[:fortified]) unless f[:fortified].nil?

    if f[:country_id].present?
      scope = scope.joins(:producer)
                   .where(producers: { country_id: f[:country_id] })
    end

    if f[:region_ids].present?
      scope = scope.where(
        "EXISTS (SELECT 1 FROM wine_regions wr
                  WHERE wr.wine_id = wines.id AND wr.region_id IN (?))",
        f[:region_ids]
      )
    end

    if f[:grape_ids].present?
      scope = scope.where(
        "EXISTS (SELECT 1 FROM wine_grapes wg
                  WHERE wg.wine_id = wines.id AND wg.grape_id IN (?))",
        f[:grape_ids]
      )
    end

    # Alcohol percentage range on the wine itself.
    if f[:alcohol_min].present? || f[:alcohol_max].present?
      conds = []
      args  = []
      if f[:alcohol_min].present?
        conds << "wines.alcohol_percentage >= ?"
        args << f[:alcohol_min]
      end
      if f[:alcohol_max].present?
        conds << "wines.alcohol_percentage <= ?"
        args << f[:alcohol_max]
      end
      scope = scope.where(conds.join(" AND "), *args)
    end

    # Vintage year and/or price range across the wine's vintages.
    vintage_filters = %i[vintage_year_min vintage_year_max price_min price_max]
    if vintage_filters.any? { |k| f[k].present? }
      conds = ["vintages.wine_id = wines.id"]
      args  = []
      conds << "vintages.year >= ?"         if f[:vintage_year_min].present?
      args  << f[:vintage_year_min]         if f[:vintage_year_min].present?
      conds << "vintages.year <= ?"         if f[:vintage_year_max].present?
      args  << f[:vintage_year_max]         if f[:vintage_year_max].present?
      if f[:price_min].present?
        conds << "vintages.price_cents >= ?"
        args << (f[:price_min].to_f * 100).round
      end
      if f[:price_max].present?
        conds << "vintages.price_cents <= ?"
        args << (f[:price_max].to_f * 100).round
      end
      scope = scope.where(
        "EXISTS (SELECT 1 FROM vintages WHERE #{conds.join(' AND ')})",
        *args
      )
    end

    # Review filters, restricted to the latest vintage that has reviews.
    review_keys = %i[score_min score_max published_from published_to
                     drink_from_min drink_from_max drink_to_min drink_to_max]
    if review_keys.any? { |k| f[k].present? }
      conds = []
      args  = []
      if f[:score_min].present?
        conds << "r.score >= ?"; args << f[:score_min]
      end
      if f[:score_max].present?
        conds << "r.score <= ?"; args << f[:score_max]
      end
      if f[:published_from].present?
        conds << "r.published_at >= ?"; args << f[:published_from].beginning_of_day
      end
      if f[:published_to].present?
        conds << "r.published_at <= ?"; args << f[:published_to].end_of_day
      end
      if f[:drink_from_min].present?
        conds << "r.drink_from >= ?"; args << f[:drink_from_min]
      end
      if f[:drink_from_max].present?
        conds << "r.drink_from <= ?"; args << f[:drink_from_max]
      end
      if f[:drink_to_min].present?
        conds << "r.drink_to >= ?"; args << f[:drink_to_min]
      end
      if f[:drink_to_max].present?
        conds << "r.drink_to <= ?"; args << f[:drink_to_max]
      end
      review_conds = conds.empty? ? "" : " AND #{conds.join(' AND ')}"
      scope = scope.where(<<~SQL.squish, *args)
        EXISTS (
          SELECT 1 FROM vintages v
          WHERE v.wine_id = wines.id
            AND v.year = (
              SELECT MAX(v2.year) FROM vintages v2
              WHERE v2.wine_id = wines.id
                AND EXISTS (SELECT 1 FROM reviews r0 WHERE r0.vintage_id = v2.id)
            )
            AND EXISTS (
              SELECT 1 FROM reviews r
              WHERE r.vintage_id = v.id#{review_conds}
            )
        )
      SQL
    end

    # Taste parameter ranges — one independent EXISTS per parameter supplied.
    Array(f[:taste_parameters]).each do |tp|
      slug = tp[:slug].to_s
      next if slug.blank?
      conds = []
      args  = [slug]
      if tp[:min].present?
        conds << "wtp.score >= ?"; args << tp[:min]
      end
      if tp[:max].present?
        conds << "wtp.score <= ?"; args << tp[:max]
      end
      score_conds = conds.empty? ? "" : " AND #{conds.join(' AND ')}"
      scope = scope.where(<<~SQL.squish, *args)
        EXISTS (
          SELECT 1 FROM wine_taste_parameters wtp
          JOIN taste_parameters tsp ON tsp.id = wtp.taste_parameter_id
          WHERE wtp.wine_id = wines.id
            AND tsp.slug = ?#{score_conds}
        )
      SQL
    end

    scope
  end

  # Use slug instead of numeric id in URLs so form submissions resolve via find_by!(slug:)
  def to_param
    slug
  end

  private

  # Pre-fill the required wine attributes so a new record is never blank.
  # Explicit values are always preserved (||= only fills in blanks).
  def set_defaults
    self.color                ||= DEFAULT_COLOR
    self.closure              ||= DEFAULT_CLOSURE
    self.alcohol_percentage   ||= DEFAULT_ALCOHOL_PERCENTAGE
    self.volume_ml            ||= DEFAULT_VOLUME
  end

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
