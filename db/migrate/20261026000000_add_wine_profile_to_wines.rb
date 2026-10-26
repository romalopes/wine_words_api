class AddWineProfileToWines < ActiveRecord::Migration[8.1]
  def change
    add_reference :wines, :wine_profile, null: true,
                  foreign_key: { to_table: :wine_profiles, on_delete: :nullify }
  end
end
