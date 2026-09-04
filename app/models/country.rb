class Country < ApplicationRecord
  has_many :grapes, dependent: :nullify
  has_many :regions, dependent: :destroy

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: { case_sensitive: false },
                   format: { with: /\A[A-Za-z]{2}\z/, message: "must be a 2-letter ISO code" },
                   length: { is: 2 }

  before_validation :generate_slug

  # Use slug instead of numeric id in URLs so form submissions resolve via find_by!(slug:)
  def to_param
    slug
  end

  private

  def generate_slug
    return if slug.present? && !name_changed?
    return if name.blank?

    base = name.to_s.parameterize.presence || "country"
    candidate = base
    i = 2
    while self.class.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{i}"
      i += 1
    end
    self.slug = candidate
  end
end