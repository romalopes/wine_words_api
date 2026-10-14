class CreateAnalyticsEvents < ActiveRecord::Migration[8.1]
  # Allowlisted content types — mirrors Comment::COMMENTABLE_TYPES
  CONTENT_TYPES = %w[Article Review Wine].freeze

  def change
    return if table_exists?(:analytics_events)

    create_table :analytics_events do |t|
      # Polymorphic content reference (allowlisted)
      t.string :viewable_type, null: false, limit: 32
      t.bigint :viewable_id, null: false

      # Identity (Phase 1 contract: account:<id> | visitor:<uuid>)
      t.string :identity, null: false, limit: 128
      # Server-only visitor fingerprint for dedup (SHA256 hash components)
      t.string :visitor_key, limit: 64

      # Server timestamp ONLY — client event time NOT accepted in V1
      t.timestamptz :viewed_at, null: false

      # Allowlisted source/navigation context
      t.string :source, limit: 32
      t.string :referrer, limit: 500
      t.string :viewport, limit: 32

      # Acceptance gate (dedup + policy)
      t.boolean :accepted, null: false, default: false

      t.timestamps
    end

    # Enforce allowlisted content types at DB level
    add_check_constraint :analytics_events,
                         "viewable_type IN ('Article','Review','Wine')",
                         name: "ck_analytics_events_viewable_type"

    # Positive, valid identifiers
    add_check_constraint :analytics_events,
                         "viewable_id > 0",
                         name: "ck_analytics_events_viewable_id_positive"

    # Identity format: account:<digits> | visitor:<uuid>
    add_check_constraint :analytics_events,
                         "identity ~ '^(account:\\\\d+|visitor:[0-9a-f-]{36})$'",
                         name: "ck_analytics_events_identity_format"

    # Composite index for daily rollup query (Phase 3/6)
    add_index :analytics_events,
              [:viewable_type, :viewable_id, :viewed_at],
              name: "idx_analytics_events_content_time"

    # Identity + time for account erasure & visitor cleanup
    add_index :analytics_events,
              [:identity, :viewed_at],
              name: "idx_analytics_events_identity_time"

    # Deduplication support (advisory lock key components)
    add_index :analytics_events,
              [:viewable_type, :viewable_id, :identity, :viewed_at],
              unique: true,
              name: "idx_analytics_events_dedup",
              where: "accepted = true"

    # Accepted filter index
    add_index :analytics_events,
              :accepted,
              name: "idx_analytics_events_accepted",
              where: "accepted = true"

    # Polymorphic association index (optional, for reverse lookups)
    add_index :analytics_events,
              [:viewable_type, :viewable_id],
              name: "idx_analytics_events_viewable"
  end
end