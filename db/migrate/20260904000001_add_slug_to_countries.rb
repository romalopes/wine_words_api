class AddSlugToCountries < ActiveRecord::Migration[7.1]
  def up
    add_column :countries, :slug, :string
    add_index :countries, :slug, unique: true

    # Backfill existing countries using the model's generate_slug logic.
    Country.reset_column_information
    Country.find_each do |country|
      country.send(:generate_slug)
      country.update_columns(slug: country.slug)
    end

    change_column_null :countries, :slug, false
  end

  def down
    remove_column :countries, :slug
  end
end
