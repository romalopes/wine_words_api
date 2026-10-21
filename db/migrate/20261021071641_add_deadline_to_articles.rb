class AddDeadlineToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :deadline, :date
  end
end
