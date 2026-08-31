class CreateCategoryJoinTables < ActiveRecord::Migration[7.0]
  def change
    create_table :wine_categories do |t|
      t.references :wine, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.timestamps
    end
    add_index :wine_categories, [:wine_id, :category_id], unique: true

    create_table :review_categories do |t|
      t.references :review, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.timestamps
    end
    add_index :review_categories, [:review_id, :category_id], unique: true

    create_table :article_categories do |t|
      t.references :article, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.timestamps
    end
    add_index :article_categories, [:article_id, :category_id], unique: true

    # Migrate existing single-category data to the join tables
    reversible do |dir|
      dir.up do
        Wine.where.not(category_id: nil).find_each do |wine|
          WineCategory.create(wine_id: wine.id, category_id: wine.category_id)
        end
        Review.where.not(category_id: nil).find_each do |review|
          ReviewCategory.create(review_id: review.id, category_id: review.category_id)
        end
        Article.where.not(category_id: nil).find_each do |article|
          ArticleCategory.create(article_id: article.id, category_id: article.category_id)
        end
      end
    end
  end
end
