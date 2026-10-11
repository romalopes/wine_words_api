class AddAnalyticsOptOutToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :analytics_opt_out, :boolean, default: false, null: false
    add_index :users, :analytics_opt_out, where: "analytics_opt_out = true", name: "idx_users_analytics_opt_out"
  end
end