class AddStatusIndexesToArticlesAndReviews < ActiveRecord::Migration[8.1]
  def change
    add_index :articles, :status
    add_index :reviews, :status
  end
end
