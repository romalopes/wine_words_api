class CreateRegionsAndWineRegionsJoinTableAndJoinTable < ActiveRecord::Migration[8.1]
  def change
        create_table :regions do |t|
      t.string :name, null: false
      t.boolean :is_state, default: false, null: false
      t.boolean :is_appellation, default: false, null: false
      t.timestamps
    end

        add_reference :regions, :country, null: false, foreign_key: true
    add_reference :regions, :parent, null: true, foreign_key: { to_table: :regions }
    add_index :regions, [:name, :parent_id], name: "index_regions_on_name_and_parent_id"

        create_table :wine_regions do |t|
      t.bigint :wine_id, null: false
      t.bigint :region_id, null: false
    end
    add_index :wine_regions, [:wine_id, :region_id], unique: true, name: "index_wine_regions_on_wine_id_and_region_id"
    add_index :wine_regions, :region_id, name: "index_wine_regions_on_region_id"
    add_foreign_key :wine_regions, :wines
    add_foreign_key :wine_regions, :regions
  end
end
