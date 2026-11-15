# Trade portal submissions (IDENTITY_206 Phase 3): DB-backed idempotency so
# retries/double-clicks return the original package.
#
# A table (not the cache) because correctness must not depend on the cache
# store (null in tests, evictable in production) and the mapping must survive
# process restarts. The digest is keyed uniquely; the package reference is the
# replay answer.
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
