class Article < ApplicationRecord
  has_many_attached :images

  belongs_to :user
  belongs_to :category, optional: true

  has_many :article_tags, dependent: :destroy
  has_many :tags, through: :article_tags

  has_many :article_wines, dependent: :destroy
  has_many :wines, through: :article_wines

  has_many :article_producers, dependent: :destroy
  has_many :producers, through: :article_producers

  has_many :article_reviews, dependent: :destroy
  has_many :reviews, through: :article_reviews

  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: %w[draft published] }

  scope :published, -> { where(status: "published") }
  scope :drafts, -> { where(status: "draft") }
  scope :visible_to, ->(user) { published.or(where(user: user)) }
  scope :recent, -> { order(created_at: :desc) }

  # Reviews shown at the bottom of the article page.
  def published_reviews
    reviews.where(article_reviews: { status: "published" })
  end
end