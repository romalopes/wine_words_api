class Review < ApplicationRecord
  has_many_attached :images
  belongs_to :vintage
  belongs_to :user
  belongs_to :category, optional: true
  has_many :review_categories, dependent: :destroy
  has_many :categories, through: :review_categories

  validates :score, presence: true,
                    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :status, presence: true, inclusion: { in: %w[draft published] }
  validates :title, presence: true

  validate :drink_window_is_consistent

  def drink_window_is_consistent
    return unless drink_from.present? || drink_to.present?

    if drink_from.present? && drink_from < (vintage&.year || 0)
      errors.add(:drink_from, "cannot be earlier than the vintage year")
    end
    if drink_from.present? && drink_to.present? && drink_to < drink_from
      errors.add(:drink_to, "cannot be earlier than Drink From")
    end
    if drink_to.present? && drink_from.blank?
      errors.add(:drink_from, "is required when Drink To is set")
    end
  end

  scope :published, -> { where(status: "published") }
  scope :drafts, -> { where(status: "draft") }
  scope :visible_to, ->(user) { where(status: "published").or(where(user: user)) }
  scope :by_recency, -> { order(created_at: :desc) }

  # Keep article-review links consistent when a review is unpublished.
  after_save :demote_article_links, if: :saved_change_to_status?

  private

  def demote_article_links
    return if status == "published"

    ArticleReview.where(review: self, status: "published").update_all(status: "draft")
  end
end
