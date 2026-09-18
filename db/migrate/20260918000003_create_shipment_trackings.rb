# Carrier-independent tracking aggregate, one per wine package.
#
# Keeping tracking in its own table (rather than only columns on the package)
# means the provider abstraction — manual entry today, Australia Post when
# credentials are configured — has a single, replaceable home. "Delivered" is
# recorded here for information only: it must NEVER automatically mark the
# package as arrived; a reviewer always confirms physical arrival.
class CreateShipmentTrackings < ActiveRecord::Migration[8.1]
  def change
    create_table :shipment_trackings do |t|
      t.references :wine_package, null: false, foreign_key: true, index: { unique: true }

      # Human label / carrier key, e.g. "Australia Post", "Aramex", "Manual".
      t.string :carrier, limit: 64
      t.string :number, limit: 128
      t.string :url, limit: 500
      # Provider used to resolve data: "manual" | "australia_post".
      t.string :provider, limit: 64, default: "manual", null: false
      t.string :status, limit: 64
      t.datetime :status_updated_at
      t.datetime :estimated_delivery_at
      t.datetime :delivered_at

      t.timestamps
    end

    add_index :shipment_trackings, :number
  end
end
