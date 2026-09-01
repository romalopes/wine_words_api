class Producer < ApplicationRecord
  MAX_LOGO_SIZE = 10.megabytes
  MAX_LOGO_DIMENSION = 5000
  ALLOWED_LOGO_TYPES = %w[image/png image/jpeg image/gif image/webp image/svg+xml].freeze
  DEFAULT_COUNTRY_CODE = "AU"

  has_many :wines, dependent: :nullify
  has_many_attached :images
  has_one_attached :logo

  belongs_to :country

  has_many :producer_regions, dependent: :destroy, autosave: true
  has_many :regions, through: :producer_regions
  has_many :producer_grapes, dependent: :destroy
  has_many :grapes, through: :producer_grapes

  enum :producer_type, {
    winery: 0,
    negociant: 1,
    cooperative: 2,
    wine_company: 3,
    independent_producer: 4
  }, default: :winery, validate: true

  validates :name, presence: true, uniqueness: true
  validates :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :producer_type, presence: true, inclusion: { in: producer_types.keys }
  validates :founded_year,
            numericality: {
              only_integer: true,
              greater_than: 0,
              less_than_or_equal_to: Date.current.year
            },
            allow_nil: true

  validate :logo_content_type_and_size, if: -> { logo.attached? }
  validate :regions_belong_to_country

  # Producers always belong to a country; new/legacy rows default to Australia.
  before_validation :set_default_country

  # Changing the producer's country invalidates its existing regions —
  # they are removed on save (newly assigned regions are kept).
  before_validation :drop_regions_of_old_country,
                    if: -> { persisted? && will_save_change_to_country_id? }

  # Use slug instead of numeric id in URLs so form submissions resolve via find_by!(slug:)
  def to_param
    slug
  end

  before_validation :generate_slug, on: :create

  private

  def set_default_country
    return if country_id.present?

    self.country = Country.find_or_create_by!(code: DEFAULT_COUNTRY_CODE) do |country|
      country.name = "Australia"
      country.continent = "Oceania"
    end
  end

  def regions_belong_to_country
    return if country_id.blank?

    foreign = producer_regions.reject(&:marked_for_destruction?)
                              .map(&:region)
                              .compact
                              .reject { |r| r.country_id == country_id }
    errors.add(:regions, "must belong to the producer's country") if foreign.any?
  end

  def logo_content_type_and_size
    blob = logo.blob
    unless ALLOWED_LOGO_TYPES.include?(blob.content_type)
      errors.add(:logo, "must be an image (PNG, JPEG, GIF, WEBP or SVG)")
    end
    return if blob.byte_size <= MAX_LOGO_SIZE

    errors.add(:logo, "must be smaller than #{MAX_LOGO_SIZE / 1.megabyte} MB")
  end

  def drop_regions_of_old_country
    producer_regions.select(&:persisted?).each(&:mark_for_destruction)
  end

  def generate_slug
    return if slug.present?
    return if name.blank?

    base = name.parameterize
    candidate = base
    suffix = 1
    while Producer.where.not(id: id).exists?(slug: candidate)
      suffix += 1
      candidate = "#{base}-#{suffix}"
    end
    self.slug = candidate
  end
end

