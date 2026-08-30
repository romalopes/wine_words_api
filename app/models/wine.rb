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
