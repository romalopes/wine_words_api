class AddSearchableToReviews < ActiveRecord::Migration[7.0]
  def change
    add_column :reviews, :searchable, :tsvector
    add_index :reviews, :searchable, using: :gin
  end
end