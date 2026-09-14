class AddPeriodToUserSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :user_subscriptions, :current_period_start, :datetime
    add_column :user_subscriptions, :current_period_end, :datetime
  end
end