class AddRankToSubscriptions < ActiveRecord::Migration[8.1]
  def up
    add_column :subscriptions, :rank, :integer
    # Backfill from position so existing rows (FREE=0 … Retail=4) stay consistent.
    execute "UPDATE subscriptions SET rank = position"

    change_column :subscriptions, :rank, :integer, null: false, default: 0
    add_index :subscriptions, :rank
  end

  def down
    remove_index :subscriptions, :rank
    remove_column :subscriptions, :rank
  end
end