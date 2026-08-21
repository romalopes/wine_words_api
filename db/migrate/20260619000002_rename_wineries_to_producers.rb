class RenameWineriesToProducers < ActiveRecord::Migration[8.1]
  def change
    rename_table :wineries, :producers
    rename_column :wines, :winery_id, :producer_id
  end
end