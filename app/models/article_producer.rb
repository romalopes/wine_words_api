class ArticleProducer < ApplicationRecord
  belongs_to :article
  belongs_to :producer

  validates :article_id, uniqueness: { scope: :producer_id }
end