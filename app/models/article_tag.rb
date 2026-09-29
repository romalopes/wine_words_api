class ArticleTag < ApplicationRecord
  belongs_to :article
  belongs_to :tag

  validates :article_id, uniqueness: { scope: :tag_id }
  # A tag is part of the article's search vector, but the join row is written
  # *after* the article is saved — so `before_save :update_search_vector` never
  # sees it, and tagging an article left the tag unsearchable until the article
  # was next saved. Reindexed inline rather than through SearchReindexJob: this
  # is one row, computed from one UPDATE, and tagging is interactive.
  after_commit :refresh_article_search_vector

  private

  def refresh_article_search_vector
    article&.refresh_search_vector!
  end
end
