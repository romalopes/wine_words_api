class AddUserToReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :reviews, :user_id, :uuid, null: false
    add_index :reviews, :user_id
    # add_foreign_key :reviews, "neon_auth.user", column: :user_id, primary_key: :id
  end
end