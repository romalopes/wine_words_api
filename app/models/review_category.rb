class ReviewCategory < ApplicationRecord
  belongs_to :review
  belongs_to :category

  validates :review_id, uniqueness: { scope: :category_id }
end
