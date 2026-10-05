class ArticleProjectReview < ApplicationRecord
  belongs_to :article_project
  belongs_to :review

  validates :review_id, uniqueness: { scope: :article_project_id }
end