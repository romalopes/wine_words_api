class Producer < ApplicationRecord
  has_many :wines, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

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