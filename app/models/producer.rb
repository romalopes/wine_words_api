class Producer < ApplicationRecord
  has_many :wines, dependent: :nullify
  has_many_attached :images

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
    while Producer.where.not(id: id).exists?(slug: candidate)
      suffix += 1
      candidate = "#{base}-#{suffix}"
    end
    self.slug = candidate
  end
end
