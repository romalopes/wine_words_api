class AddSearchableToArticles < ActiveRecord::Migration[7.0]
  def change
    add_column :articles, :searchable, :tsvector
    add_index :articles, :searchable, using: :gin
  end
end