class CreateNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_preferences do |t|
      # Singleton-per-user: unique index straight on the reference
      # (`t.references` creates its own index otherwise).
      t.references :user, null: false, foreign_key: { on_delete: :cascade },
                    index: { unique: true }
      # In-app delivery of follow-based notifications (on by default).
      t.boolean :follow_in_app, null: false, default: true
      # Immediate email per follow event (off by default — comments would
      # otherwise email on every single event).
      t.boolean :follow_email, null: false, default: false
      # Digest cadence for follow events: none | daily | weekly.
      t.string :digest_cadence, null: false, default: "none"
      t.datetime :digest_last_sent_at
      t.datetime :digest_last_error_at
      t.text :digest_last_error

      t.timestamps
    end

    add_check_constraint :notification_preferences,
                         "digest_cadence IN ('none', 'daily', 'weekly')",
                         name: "notification_preferences_digest_cadence_check"
  end
end
