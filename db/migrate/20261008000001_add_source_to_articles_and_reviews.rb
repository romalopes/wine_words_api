class AddSourceToArticlesAndReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :source, :string, limit: 32, default: "manual", null: false
    add_column :reviews, :source, :string, limit: 32, default: "manual", null: false
    add_index :articles, :source
    add_index :reviews, :source
  end
end
