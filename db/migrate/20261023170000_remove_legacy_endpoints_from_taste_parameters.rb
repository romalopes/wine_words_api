class RemoveLegacyEndpointsFromTasteParameters < ActiveRecord::Migration[8.1]
  def up
    remove_column :taste_parameters, :low, :string
    remove_column :taste_parameters, :high, :string
  end

  def down
    add_column :taste_parameters, :low, :string
    add_column :taste_parameters, :high, :string

    execute <<~SQL.squish
      UPDATE taste_parameters
      SET low = label_1, high = label_5
    SQL
  end
end