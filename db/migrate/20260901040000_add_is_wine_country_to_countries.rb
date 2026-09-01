class AddIsWineCountryToCountries < ActiveRecord::Migration[7.1]
  def up
    unless column_exists?(:countries, :is_wine_country)
      add_column :countries, :is_wine_country, :boolean, default: false, null: false
    end

    # A country is a wine country when it has wine regions mapped to it.
    Country.where(id: Region.select(:country_id)).update_all(is_wine_country: true)
  end

  def down
    remove_column :countries, :is_wine_country
  end
end
