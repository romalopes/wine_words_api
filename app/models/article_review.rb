class ArticleReview < ApplicationRecord
  belongs_to :article
  belongs_to :review

  validates :article_id, uniqueness: { scope: :review_id }
  validates :status, presence: true, inclusion: { in: %w[draft published] }

  # A link can only be published when the underlying review is published.
  validate :review_must_be_published

  before_save :demote_if_review_unpublished

  scope :published, -> { where(status: "published") }

  private

  def review_must_be_published
    return unless status == "published"

    errors.add(:status, "cannot be published unless the review is published") if review&.status != "published"
  end

  def demote_if_review_unpublished
    self.status = "draft" if status == "published" && review&.status != "published"
  end
end