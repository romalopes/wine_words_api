# Trade portal submissions (IDENTITY_206 Phase 3): DB-backed idempotency so
# retries/double-clicks return the original package. A table (not the cache)
# because correctness must not depend on the cache store (null in tests,
# shared Redis in production) and the key must survive process restarts.
class CreateTradeIdempotencyKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :trade_idempotency_keys do |t|
      t.string :key_digest, null: false
      t.references :wine_package, null: false, foreign_key: true

      t.timestamps
    end

    add_index :trade_idempotency_keys, :key_digest, unique: true
  end
end
# table. Submitters (or guest-token holders) and Wine Words editors converse
# per package; `internal_note` marks staff-only lines.
class CreateWinePackageMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :wine_package_messages do |t|
      t.references :wine_package, null: false, foreign_key: true
      # Nullable: a guest-token submitter may converse before claiming an
      # account (sender_type "submitter", sender_id nil).
      t.references :sender, foreign_key: { to_table: :users }
      t.string :sender_type, limit: 32, null: false, default: "submitter"
      t.text :body, null: false
      t.boolean :internal_note, default: false, null: false

      t.timestamps
    end

    add_index :wine_package_messages, :internal_note
  end
end