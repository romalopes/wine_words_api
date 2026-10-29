class CreateGrapeRegionsJoinTable < ActiveRecord::Migration[8.1]
  def change
    create_table :grape_regions do |t|
      t.bigint :grape_id, null: false
      t.bigint :region_id, null: false
    end
    add_index :grape_regions, [:grape_id, :region_id], unique: true, name: "index_grape_regions_on_grape_id_and_region_id"
    add_index :grape_regions, :region_id, name: "index_grape_regions_on_region_id"
    add_foreign_key :grape_regions, :grapes
    add_foreign_key :grape_regions, :regions
  end
end