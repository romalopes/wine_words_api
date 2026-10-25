class CreateNotificationEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_events do |t|
      t.string :event_type, null: false
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.bigint :actor_id
      t.datetime :occurred_at, null: false
      t.jsonb :affected_targets, null: false, default: []
      t.jsonb :metadata, null: false, default: {}
      t.string :idempotency_key, null: false
      t.datetime :processing_started_at
      t.datetime :processed_at
      t.datetime :failed_at
      t.integer :attempts, null: false, default: 0
      t.text :last_error

      t.timestamps
    end

    add_index :notification_events, :idempotency_key, unique: true
    add_index :notification_events, [:subject_type, :subject_id]
    add_index :notification_events, :processed_at,
              where: "processed_at IS NULL AND failed_at IS NULL",
              name: :index_notification_events_pending
    add_foreign_key :notification_events, :users, column: :actor_id,
                    on_delete: :nullify
  end
end
