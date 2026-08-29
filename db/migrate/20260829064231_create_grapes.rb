class CreateGrapes < ActiveRecord::Migration[8.1]
  def change
    create_table :grapes do |t|
      t.string :name, null: false
      t.string :color
      t.string :origin_country
      t.text :main_regions, array: true, default: []
      t.text :synonyms, array: true, default: []
      t.boolean :is_blending_grape, default: false, null: false
      t.text :notes, array: true, default: []
      t.text :serving

      t.timestamps
    end
    add_index :grapes, :name, unique: true
  end
end
