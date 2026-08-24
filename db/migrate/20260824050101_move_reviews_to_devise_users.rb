class MoveReviewsToDeviseUsers < ActiveRecord::Migration[8.1]
  def up
    fk_name = connection.foreign_keys(:reviews)
                        .find { |fk| fk.to_table.delete('"') == "neon_auth.user" }&.name
    remove_foreign_key :reviews, name: fk_name if fk_name

    # Old neon_auth user ids are UUIDs and cannot be mapped to the new
    # Devise users table (bigint ids), so clear them.
    change_column_null :reviews, :user_id, true
    update("UPDATE reviews SET user_id = NULL")

    execute("ALTER TABLE reviews ALTER COLUMN user_id TYPE bigint USING NULL")

    add_foreign_key :reviews, :users, column: :user_id
  end

  def down
    remove_foreign_key :reviews, :users, column: :user_id
    change_column :reviews, :user_id, :uuid
  end
end