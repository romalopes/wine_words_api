class AddFortifiedToWines < ActiveRecord::Migration[8.1]
  def change
    add_column :wines, :fortified, :boolean, default: false, null: false
  end
end
