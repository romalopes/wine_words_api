class CreateWineProfileTasteParameters < ActiveRecord::Migration[8.1]
  def change
    create_table :wine_profile_taste_parameters do |t|
      t.references :wine_profile, null: false, foreign_key: true
      t.references :taste_parameter, null: false, foreign_key: true

      t.integer :score
      t.timestamps
    end

    add_index :wine_profile_taste_parameters, [ :wine_profile_id, :taste_parameter_id ], unique: true
    add_index :wine_profile_taste_parameters, [ :taste_parameter_id, :wine_profile_id ], unique: true
  end
end
