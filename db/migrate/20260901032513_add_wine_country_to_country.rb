class AddWineCountryToCountry < ActiveRecord::Migration[8.1]
  def up
    add_column :countries, :is_wine_country, :boolean, default: false, null: false
  end
  def down
    remove_column :countries, :is_wine_country, :boolean
  end
end
