class RemoveRegionFromWines < ActiveRecord::Migration[8.1]
  def change
    remove_column :wines, :region
  end
end
