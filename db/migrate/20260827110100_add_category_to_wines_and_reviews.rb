class AddCategoryToWinesAndReviews < ActiveRecord::Migration[7.1]
  def change
    add_reference :wines, :category, null: true, foreign_key: true
    add_reference :reviews, :category, null: true, foreign_key: true
  end
end