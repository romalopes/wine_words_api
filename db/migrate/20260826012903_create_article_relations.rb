class CreateArticleRelations < ActiveRecord::Migration[8.0]
  def change
    create_table :article_tags do |t|
      t.references :article, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    add_index :article_tags, [:article_id, :tag_id], unique: true

    create_table :article_wines do |t|
      t.references :article, null: false, foreign_key: true
      t.references :wine, null: false, foreign_key: true

      t.timestamps
    end
    add_index :article_wines, [:article_id, :wine_id], unique: true

    create_table :article_producers do |t|
      t.references :article, null: false, foreign_key: true
      t.references :producer, null: false, foreign_key: true

      t.timestamps
    end
    add_index :article_producers, [:article_id, :producer_id], unique: true

    create_table :article_reviews do |t|
      t.references :article, null: false, foreign_key: true
      t.references :review, null: false, foreign_key: true
      t.string :status, default: "draft", null: false

      t.timestamps
    end
    add_index :article_reviews, [:article_id, :review_id], unique: true
  end
end