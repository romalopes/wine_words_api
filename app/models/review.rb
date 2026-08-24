class Review < ApplicationRecord
  belongs_to :vintage
  belongs_to :user

  validates :score, presence: true,
                    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :status, presence: true, inclusion: { in: %w[draft published] }

  scope :published, -> { where(status: "published") }
  scope :drafts, -> { where(status: "draft") }
  scope :visible_to, ->(user) { where(status: "published").or(where(user: user)) }
  scope :by_recency, -> { order(created_at: :desc) }
end