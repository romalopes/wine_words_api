# Immutable-ish event history for a package's shipment. Events are keyed by
# package (tracking is 1:1 with a package) so a package can record events even
# before a ShipmentTracking row exists (e.g. manually noted milestones).
#
# `external_id` is the carrier's event identifier: the unique index on
# (wine_package_id, external_id) makes re-importing the same carrier payload
# idempotent. PostgreSQL treats NULLs as distinct, so manual events without an
# external_id are unaffected.
class CreateShipmentTrackingEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :shipment_tracking_events do |t|
      t.references :wine_package, null: false, foreign_key: true

      t.string :status, null: false, limit: 64
      t.datetime :event_at
      t.string :location, limit: 255
      t.text :message
      t.string :external_id, limit: 128
      # Raw provider payload, kept for debugging/replay. jsonb, defaults to {}.
      t.jsonb :raw_data, null: false, default: {}

      t.timestamps
    end

    add_index :shipment_tracking_events, [ :wine_package_id, :event_at ]
    add_index :shipment_tracking_events, [ :wine_package_id, :external_id ],
              unique: true,
              name: "index_shipment_tracking_events_on_package_and_external_id"
  end
end
