class Review < ApplicationRecord
  has_many_attached :images
  belongs_to :vintage
  belongs_to :user

  validates :score, presence: true,
                    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :status, presence: true, inclusion: { in: %w[draft published] }
  validates :title, presence: true

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
