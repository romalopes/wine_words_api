class CreateArticleProjectReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :article_project_reviews do |t|
      t.references :article_project, null: false, foreign_key: true
      t.references :review, null: false, foreign_key: true
      t.timestamps
    end

    add_index :article_project_reviews, [:article_project_id, :review_id], unique: true
  end
end