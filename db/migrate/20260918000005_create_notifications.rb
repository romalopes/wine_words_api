# A single, reusable notification event backing both email delivery and a
# future in-app notification list. Wine-package deadline reminders are the
# first type ("wine_package_deadline"), but the model is intentionally generic
# (recipient + type + optional polymorphic notifiable).
#
# Idempotency: the unique index on
#   (wine_package_id, notification_type, scheduled_date)
# guarantees a given reminder for a given package, type and day can only be
# created once — the scheduler can run as often as it likes without spamming.
class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.string :notification_type, null: false, limit: 64

      # What the notification is about (e.g. the WinePackage, or later any
      # other record). Polymorphic so new notification types need no migration.
      t.references :notifiable, polymorphic: true, null: true, index: false

      # Denormalised for the idempotency unique index and for cheap filtering.
      t.references :wine_package, null: true, foreign_key: true
      t.date :scheduled_date

      t.text :message
      t.datetime :sent_at
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [ :notifiable_type, :notifiable_id ]
    add_index :notifications, [ :recipient_id, :read_at ]
    add_index :notifications,
              [ :wine_package_id, :notification_type, :scheduled_date ],
              unique: true,
              name: "index_notifications_on_package_type_and_scheduled_date"
  end
end
