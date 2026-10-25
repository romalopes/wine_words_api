class AddFailedAtToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :failed_at, :datetime
    add_index :notifications, :failed_at
  end
end