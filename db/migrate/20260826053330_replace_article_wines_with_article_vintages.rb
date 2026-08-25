class ReplaceArticleWinesWithArticleVintages < ActiveRecord::Migration[8.0]
  def change
    create_table :article_vintages do |t|
      t.references :article, null: false, foreign_key: true
      t.references :vintage, null: false, foreign_key: true

      t.timestamps
    end
    add_index :article_vintages, [:article_id, :vintage_id], unique: true

    drop_table :article_wines
  end
end