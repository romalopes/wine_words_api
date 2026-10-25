class ExtendNotificationsForFollows < ActiveRecord::Migration[8.1]
  def change
    add_reference :notifications, :notification_event, null: true,
                  foreign_key: { on_delete: :nullify }
    add_reference :notifications, :actor, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
    add_column :notifications, :delivered_at, :datetime
    add_column :notifications, :target_path, :string
    add_column :notifications, :target_label, :string

    # Per-event dedup for follow-based deliveries: one notification per
    # (recipient, event). Package reminders keep their existing
    # (wine_package, type, scheduled_date) index — NULLs are distinct in
    # PostgreSQL, so the partial index never conflicts with them.
    add_index :notifications, [:recipient_id, :notification_event_id],
              unique: true,
              where: "notification_event_id IS NOT NULL",
              name: :index_notifications_on_recipient_and_event

    # Backfill: existing package rows were delivered when the email went out.
    up_only { execute <<~SQL }
      UPDATE notifications
      SET delivered_at = sent_at
      WHERE notification_event_id IS NULL AND sent_at IS NOT NULL
    SQL
  end
end
