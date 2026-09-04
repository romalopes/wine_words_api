class Article < ApplicationRecord
  has_many_attached :images

  belongs_to :user
  belongs_to :category, optional: true
  has_many :article_categories, dependent: :destroy
  has_many :categories, through: :article_categories

  has_many :article_tags, dependent: :destroy
  has_many :tags, through: :article_tags

  # Articles link to vintages directly; the relationship to wines goes
  # through those vintages.
  has_many :article_vintages, dependent: :destroy
  has_many :vintages, through: :article_vintages
  has_many :wines, through: :vintages

  has_many :article_producers, dependent: :destroy
  has_many :producers, through: :article_producers

  has_many :article_reviews, dependent: :destroy
  has_many :reviews, through: :article_reviews

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[draft published] }

  before_validation :generate_slug

  # Use slug instead of numeric id in URLs so lookups resolve via find_by!(slug:)
  def to_param
    slug
  end

  scope :published, -> { where(status: "published") }
  scope :drafts, -> { where(status: "draft") }
  scope :visible_to, ->(user) { published.or(where(user: user)) }
  scope :recent, -> { order(created_at: :desc) }

  # Reviews shown at the bottom of the article page.
  def published_reviews
    reviews.where(article_reviews: { status: "published" })
  end

  private

  def generate_slug
    return if slug.present? && !title_changed?
    return if title.blank?

    base = title.to_s.parameterize.presence || "article"
    candidate = base
    i = 2
    while self.class.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{i}"
      i += 1
    end
    self.slug = candidate
  end
end