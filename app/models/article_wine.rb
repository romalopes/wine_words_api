class ArticleWine < ApplicationRecord
  belongs_to :article
  belongs_to :wine

  validates :article_id, uniqueness: { scope: :wine_id }
end