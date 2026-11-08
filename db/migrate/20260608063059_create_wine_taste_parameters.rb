class CreateWineTasteParameters < ActiveRecord::Migration[6.1]
  def change
    create_table :wine_taste_parameters do |t|
      t.references :wine, null: false, foreign_key: true
      t.references :taste_parameter, null: false, foreign_key: true
      t.integer :score
      t.timestamps
    end

    add_index :wine_taste_parameters, [ :wine_id, :taste_parameter_id ], unique: true
    add_index :wine_taste_parameters, [ :taste_parameter_id, :wine_id ], unique: true
  end
end
