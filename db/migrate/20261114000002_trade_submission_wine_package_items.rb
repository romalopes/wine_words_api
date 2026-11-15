# Trade portal submissions (IDENTITY_206): immutable wine-line snapshots.
#
# Extends WinePackageItem (issue #199 already added proposed_wine_name /
# proposed_vintage_year for producer requests — those remain the canonical
# "snapshot name/vintage" columns and are aliased in Ruby, not renamed here).
# The catalogue linkage columns (`catalogue_wine_id`) plus per-line editorial
# (`item_status`) and receipt (`received_*`) state support Phases 7/12/13.
class TradeSubmissionWinePackageItems < ActiveRecord::Migration[8.1]
  def change
    # NOTE: the existing `condition` and `received_at` columns already capture
    # receipt condition/date — they are REUSED (no received_condition column).
    change_table :wine_package_items, bulk: true do |t|
      t.string :snapshot_region, limit: 128
      t.string :snapshot_appellation, limit: 128
      t.string :snapshot_grape_varieties, limit: 255
      t.decimal :snapshot_abv, precision: 4, scale: 1
      t.integer :snapshot_volume_ml
      t.string :snapshot_closure_type, limit: 64
      t.text :snapshot_tasting_notes
      t.string :snapshot_technical_sheet_url, limit: 500
      t.decimal :snapshot_trade_price, precision: 10, scale: 2
      t.decimal :snapshot_retail_price, precision: 10, scale: 2
      t.boolean :snapshot_sample_available, default: false, null: false
      t.integer :snapshot_sample_quantity

      t.bigint :catalogue_wine_id
      t.string :item_status, limit: 32, default: "pending", null: false
      t.text :received_notes
    end

    add_index :wine_package_items, :catalogue_wine_id
    add_index :wine_package_items, :item_status
    add_foreign_key :wine_package_items, :wines, column: :catalogue_wine_id
  end
end