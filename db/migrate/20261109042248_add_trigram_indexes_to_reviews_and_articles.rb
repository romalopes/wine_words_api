class AddTrigramIndexesToReviewsAndArticles < ActiveRecord::Migration[8.1]
  def change
    # Trigram indexes for pg_trgm similarity search (word_similarity, strict_word_similarity)
    # These indexes are required for word_similarity to work correctly
    add_index :reviews, :title, name: "index_reviews_on_title_trgm", using: :gin, opclass: :gin_trgm_ops
    add_index :reviews, :comment, name: "index_reviews_on_comment_trgm", using: :gin, opclass: :gin_trgm_ops

    add_index :articles, :title, name: "index_articles_on_title_trgm", using: :gin, opclass: :gin_trgm_ops
    add_index :articles, :body, name: "index_articles_on_body_trgm", using: :gin, opclass: :gin_trgm_ops
  end
end
