class AddDeadlineToReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :reviews, :deadline, :date
  end
end
