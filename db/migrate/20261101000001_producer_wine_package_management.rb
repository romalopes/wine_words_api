class ProducerWinePackageManagement < ActiveRecord::Migration[8.1]
  def up
    # ------------------------------------------------------------------
    # Issue #199 — producer Wine Package management (Phase 1).
    #
    # All changes are additive: existing editorial workflows are untouched.
    # ------------------------------------------------------------------

    # Producer-owned package metadata. `notes` remains editorial-only;
    # `producer_notes`/`shipping_notes` are producer-visible.
    change_table :wine_packages, bulk: true do |t|
      t.bigint :requested_by_id
      t.datetime :submitted_at
      t.string :producer_reference, limit: 128
      t.text :producer_notes
      t.text :shipping_notes
      t.text :internal_notes
    end
    add_index :wine_packages, :requested_by_id
    add_foreign_key :wine_packages, :users, column: :requested_by_id

    # A producer request may contain wines that are not in the catalogue yet;
    # the proposal is stored on the item and resolved later by the editors.
    change_table :wine_package_items, bulk: true do |t|
      t.string :proposed_wine_name, limit: 255
      t.integer :proposed_vintage_year
    end

    # Producer-supplied dispatch details on the tracking row.
    change_table :shipment_trackings, bulk: true do |t|
      t.date :dispatch_date
      t.integer :parcel_count
    end

    # Typed package attachments (bottle photos, postal receipts, technical
    # sheets ...) with per-file visibility. The bytes live in Active Storage
    # (Cloudflare R2 in production), the metadata lives here.
    create_table :wine_package_attachments do |t|
      t.references :wine_package, null: false, foreign_key: true
      t.references :wine_package_item, foreign_key: true
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }
      t.string :attachment_type, null: false, default: "other"
      t.string :visibility, null: false, default: "shared"
      t.string :caption
      t.timestamps
    end
    add_index :wine_package_attachments, [ :wine_package_id, :attachment_type ]

    # Application activity timeline: submitted, accepted, rejected, arrival
    # confirmed, review published ... Raw carrier events stay in
    # `shipment_tracking_events` and are merged read-only in the timeline
    # projection — never duplicated here.
    create_table :wine_package_events do |t|
      t.references :wine_package, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :event_type, null: false
      t.string :description
      t.string :visibility, null: false, default: "shared"
      t.datetime :occurred_at, null: false
      t.jsonb :metadata, null: false, default: {}
      t.string :idempotency_key
      t.timestamps
    end
    add_index :wine_package_events, [ :wine_package_id, :occurred_at ]
    add_index :wine_package_events, [ :wine_package_id, :idempotency_key ],
              unique: true, where: "idempotency_key IS NOT NULL"

    # Lifecycle notifications go to several people (producer members AND
    # editors), so the old one-row-per-package/type/day index must become a
    # per-recipient index. Deadline reminders (single recipient) keep working:
    # one reminder row per recipient/day/type is what the scheduler produces.
    remove_index :notifications, name: "index_notifications_on_package_type_and_scheduled_date"
    add_index :notifications, [ :wine_package_id, :notification_type, :scheduled_date, :recipient_id ],
              name: "index_notifications_on_package_type_date_recipient",
              unique: true,
              where: "wine_package_id IS NOT NULL"
  end

  def down
    remove_index :notifications, name: "index_notifications_on_package_type_date_recipient"
    add_index :notifications, [ :wine_package_id, :notification_type, :scheduled_date ],
              name: "index_notifications_on_package_type_and_scheduled_date", unique: true

    remove_index :wine_package_events, [ :wine_package_id, :idempotency_key ]
    remove_index :wine_package_events, [ :wine_package_id, :occurred_at ]
    drop_table :wine_package_events

    remove_index :wine_package_attachments, [ :wine_package_id, :attachment_type ]
    drop_table :wine_package_attachments

    remove_column :shipment_trackings, :dispatch_date
    remove_column :shipment_trackings, :parcel_count

    remove_column :wine_package_items, :proposed_vintage_year
    remove_column :wine_package_items, :proposed_wine_name

    remove_foreign_key :wine_packages, :users, column: :requested_by_id
    remove_index :wine_packages, :requested_by_id
    remove_columns :wine_packages, :requested_by_id, :submitted_at,
                   :producer_reference, :producer_notes, :shipping_notes, :internal_notes
  end
end
