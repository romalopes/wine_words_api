class RenameUsersNameToUserName < ActiveRecord::Migration[8.1]
  def up
    rename_column :users, :name, :user_name

    # Dedup so the unique index below can be added safely. Existing data had
    # exactly one duplicate group; append a numeric suffix to the later rows.
    User.where.not(id: User.group(:user_name).pluck("MIN(id)")).order(:id).find_each do |user|
      base = user.user_name
      suffix = 2
      suffix += 1 while User.exists?(user_name: "#{base}#{suffix}")
      user.update_column(:user_name, "#{base}#{suffix}")
    end

    add_index :users, :user_name, unique: true
  end

  def down
    remove_index :users, :user_name
    rename_column :users, :user_name, :name
  end
end
