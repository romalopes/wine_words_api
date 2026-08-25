class ArticleVintage < ApplicationRecord
  belongs_to :article
  belongs_to :vintage

  validates :vintage_id, uniqueness: { scope: :article_id }
end