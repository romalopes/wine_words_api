class CreateWineProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :wine_profiles do |t|
      t.string :identification
      t.string :name
      t.string :color
      t.text :grapes
      t.text :regions
      t.text :notes
      t.text :serving
      t.text :parameters

      t.timestamps
    end
  end
end
