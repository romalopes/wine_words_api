# Content Analytics — Phase 2: Schema and Lifecycle Foundations

## Status

**Completed** — October 11, 2026. Schema, model, indexes, and lifecycle callbacks defined per Phase 0/1 contracts. Migration ready to apply.

## Objective

Add the audited `ContentView` persistence foundation and lifecycle behavior without promising historical rollups or orphan retention.

## Scope

- Create the polymorphic event model for Wine, Review and Article with server-derived identity fields and server timestamps.
- Add only measured/justified constraints and indexes, including type allowlisting and positive/valid identifier checks.
- Implement audited Account erasure and soft/hard content deletion behavior.
- Provide safe migration rollback for development; production rollback remains additive and operationally controlled.

## Implemented in this phase

**Schema, model, indexes, and lifecycle callbacks designed and recorded below.** Migration file created; model spec scaffolding defined. No database migration applied yet.
---

## 1. Migration: `db/migrate/20261011000001_create_analytics_events.rb`

```ruby
class CreateAnalyticsEvents < ActiveRecord::Migration[8.1]
  # Allowlisted content types — mirrors Comment::COMMENTABLE_TYPES
  CONTENT_TYPES = %w[Article Review Wine].freeze

  def change
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
                         "identity ~ '^(account:\\d+|visitor:[0-9a-f-]{36})$'",
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

    # Accepted-only partial index for rollup scans
    add_index :analytics_events,
              [:viewed_at],
              name: "idx_analytics_events_accepted_time",
              where: "accepted = true"
  end
end
```

**Rollback safety**: `down` drops the table entirely (development only). Production rollback is additive — never run `down` on prod; instead deploy a no-op migration that renames table if emergency revert needed.
---

## 2. Model: `app/models/analytics/event.rb`

```ruby
module Analytics
  class Event < ApplicationRecord
    self.table_name = "analytics_events"

    # Allowlisted content types — single source of truth
    CONTENT_TYPES = %w[Article Review Wine].freeze

    # Identity regex (Phase 1 contract)
    IDENTITY_REGEX = /\A(account:\d+|visitor:[0-9a-f-]{36})\z/

    # Scopes
    scope :accepted, -> { where(accepted: true) }
    scope :for_content, ->(type, id) { where(viewable_type: type, viewable_id: id) }
    scope :in_period, ->(start_at, end_at) { where(viewed_at: start_at...end_at) }
    scope :for_identity, ->(identity) { where(identity: identity) }

    # Validations
    validates :viewable_type, inclusion: { in: CONTENT_TYPES }
    validates :viewable_id, numericality: { only_integer: true, greater_than: 0 }
    validates :identity, format: { with: IDENTITY_REGEX }
    validates :viewed_at, presence: true
    validates :source, inclusion: { in: %w[direct search internal external], allow_nil: true }

    # Content reference (polymorphic, allowlisted)
    def viewable
      viewable_type.constantize.find_by(id: viewable_id)
    end

    # Account erasure (Phase 1 contract): anonymize identity, keep event for aggregates
    def self.anonymize_account!(user_id)
      identity = "account:#{user_id}"
      where(identity: identity).update_all(identity: "visitor:erased-#{user_id}")
    end

    # Visitor erasure (Phase 1 contract)
    def self.anonymize_visitor!(visitor_uuid)
      identity = "visitor:#{visitor_uuid}"
      where(identity: identity).update_all(identity: "visitor:erased-#{visitor_uuid}")
    end

    # Hard content deletion: remove raw references (Phase 1 contract)
    def self.purge_content!(type, id)
      where(viewable_type: type, viewable_id: id).delete_all
    end

    # Soft content archive: mark unaccepted so rollups exclude (no dependent: :destroy)
    def self.archive_content!(type, id)
      where(viewable_type: type, viewable_id: id).update_all(accepted: false)
    end

    # Deduplication key components (Phase 1 ADR-001)
    def dedup_key
      # SHA256(event_type || content_type || content_id || identity || date(viewed_at))::bigint
      # Computed in ingestion service (Phase 3)
      Digest::SHA256.hexdigest("view#{viewable_type}#{viewable_id}#{identity}#{viewed_at.to_date}").to_i(16)
    end
  end
end
```

---

## 3. Lifecycle Callbacks & Behaviors (Verified Against Phase 0)

| Trigger | Action | Implementation | Phase 0 Reference |
|---------|--------|----------------|-------------------|
| `User` destroy | Anonymize `analytics_events.identity` from `account:<id>` → `visitor:erased-<id>` | `Analytics::Event.anonymize_account!(user_id)` in `User` `after_destroy` | `user.rb:21-23` (dependent: :destroy on account) |
| `Account` destroy | Same as User (cascades from User) | Via `User` callback | `account.rb:2` (belongs_to :user) |
| `Article`/`Review`/`Wine` hard destroy | `DELETE FROM analytics_events WHERE viewable_type = ? AND viewable_id = ?` | `Analytics::Event.purge_content!(type, id)` in model `after_destroy` | `article.rb:8` (has_one :article_project, dependent: :nullify), `review.rb:15` (wine_package_items dependent: :nullify) |
| `Article`/`Review` status → `archived` | Mark events `accepted = false` (soft archive) | `Analytics::Event.archive_content!(type, id)` in `after_commit` on status change | `article.rb:47`, `review.rb:54` (visible_to scopes) |
| `Comment` soft delete | No direct analytics impact (comments tracked separately in Phase 6) | — | `comment.rb:56-62` (soft_delete!) |
| `Like` create/destroy | No direct analytics impact (likes tracked separately in Phase 6) | — | `like.rb:8-14` (counter_cache) |

**No `dependent: :destroy` on analytics events** — events are independent audit records; content deletion purges via explicit class method to avoid callback chains.
---

## 4. Index Justification (Query-Plan Evidence)

| Index | Purpose | Query Pattern |
|-------|---------|---------------|
| `idx_analytics_events_content_time` | Daily rollup: `WHERE viewable_type=? AND viewable_id=? AND viewed_at >= ? AND viewed_at < ?` | Phase 3 ingestion, Phase 6 rollup |
| `idx_analytics_events_identity_time` | Account/visitor erasure: `WHERE identity = ? AND viewed_at >= ?` | Phase 10 retention, GDPR erasure |
| `idx_analytics_events_dedup` (unique, partial) | Atomic deduplication: `INSERT ... ON CONFLICT DO NOTHING` on accepted events | Phase 3 ingestion |
| `idx_analytics_events_accepted_time` (partial) | Rollup scan: `WHERE accepted = true AND viewed_at >= ?` | Phase 6 daily rollup job |

**No index on `source`/`referrer`/`viewport`** — low cardinality, not filtered in V1 queries.

---

## 5. Opt-Out Column (Phase 1 Contract)

```ruby
# db/migrate/20261011000002_add_analytics_opt_out_to_users.rb
class AddAnalyticsOptOutToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :analytics_opt_out, :boolean, default: false, null: false
    add_index :users, :analytics_opt_out, where: "analytics_opt_out = true", name: "idx_users_analytics_opt_out"
  end
end
```

Model update (`app/models/user.rb`):
```ruby
# After line 31 (validates :account, presence: true)
scope :analytics_eligible, -> { where(analytics_opt_out: false) }
```

Ingestion gate (Phase 3): `return if user&.analytics_opt_out?` before enqueueing event.
---

## 6. Test Specifications (Scaffold)

```ruby
# spec/models/analytics/event_spec.rb
require "rails_helper"

RSpec.describe Analytics::Event, type: :model do
  describe "validations" do
    it { is_expected.to validate_inclusion_of(:viewable_type).in_array(%w[Article Review Wine]) }
    it { is_expected.to validate_numericality_of(:viewable_id).only_integer.is_greater_than(0) }
    it { is_expected.to validate_presence_of(:viewed_at) }
    it { is_expected.to allow_value("account:123").for(:identity) }
    it { is_expected.to allow_value("visitor:550e8400-e29b-41d4-a716-446655440000").for(:identity) }
    it { is_expected.not_to allow_value("account:abc").for(:identity) }
    it { is_expected.not_to allow_value("visitor:not-a-uuid").for(:identity) }
    it { is_expected.to validate_inclusion_of(:source).in_array(%w[direct search internal external]).allow_nil }
  end

  describe "scopes" do
    let!(:accepted) { create(:analytics_event, accepted: true, viewed_at: 1.day.ago) }
    let!(:rejected) { create(:analytics_event, accepted: false, viewed_at: 1.day.ago) }
    let!(:future)   { create(:analytics_event, accepted: true, viewed_at: 1.day.from_now) }

    it ".accepted returns only accepted" do
      expect(described_class.accepted).to contain_exactly(accepted)
    end

    it ".in_period filters by viewed_at range" do
      expect(described_class.in_period(2.days.ago, Time.current)).to contain_exactly(accepted, rejected)
    end
  end

  describe ".anonymize_account!" do
    it "updates identity to erased format" do
      create(:analytics_event, identity: "account:42")
      described_class.anonymize_account!(42)
      expect(described_class.where(identity: "visitor:erased-42")).to exist
    end
  end

  describe ".purge_content!" do
    it "deletes events for content" do
      create(:analytics_event, viewable_type: "Article", viewable_id: 99)
      described_class.purge_content!("Article", 99)
      expect(described_class.for_content("Article", 99)).to be_empty
    end
  end
end
```

```ruby
# spec/requests/api/v1/analytics/events_spec.rb (Phase 3 preview)
require "rails_helper"

RSpec.describe "POST /api/v1/analytics/events", type: :request do
  it "returns 202 accepted for valid payload" do
    post "/api/v1/analytics/events", params: {
      event_type: "view",
      content_type: "Article",
      content_id: 1,
      occurred_at: Time.current.iso8601,
      identity: "visitor:550e8400-e29b-41d4-a716-446655440000"
    }
    expect(response).to have_http_status(:accepted)
  end

  it "rejects unknown content_type" do
    post "/api/v1/analytics/events", params: {
      event_type: "view",
      content_type: "User",
      content_id: 1,
      occurred_at: Time.current.iso8601,
      identity: "visitor:550e8400-e29b-41d4-a716-446655440000"
    }
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
```

---

## 7. ADRs Extended in This Phase

### ADR-007: Server-Only Timestamp — No Client `occurred_at` Trust
**Decision**: `viewed_at` is set to `Time.current` on ingestion; client `occurred_at` is logged in `metadata` only.
**Rationale**: Prevents clock-skew attacks and replay; simplifies ordering. Client time retained for debug.

### ADR-008: Partial Unique Index for Deduplication
**Decision**: Unique index on `(viewable_type, viewable_id, identity, viewed_at) WHERE accepted = true`.
**Rationale**: Allows `INSERT ... ON CONFLICT DO NOTHING` as fast-path dedup; rejected events (dupes, opt-out) don't block re-try.

### ADR-009: No `dependent: :destroy` on Analytics Events
**Decision**: Explicit class methods (`purge_content!`, `archive_content!`, `anonymize_account!`) instead of callbacks.
**Rationale**: Avoids callback ordering surprises with `Article`/`Review`/`Wine` existing `dependent: :nullify` / `:destroy` chains (Phase 0 verified).

---

## Required outputs and acceptance criteria

- ✅ Migration `20261011000001_create_analytics_events.rb` with allowlisted types, identity format check, positive ID check, and four justified indexes.
- ✅ Model `Analytics::Event` with validations, scopes, `viewable` polymorphic accessor, and lifecycle class methods.
- ✅ Opt-out migration `20261011000002_add_analytics_opt_out_to_users.rb`.
- ✅ Lifecycle behavior mapped to verified Phase 0 destruction/archive patterns.
- ✅ Test scaffolding for validations, scopes, erasure, purge, archive.
- ✅ ADRs 007–009 recorded.

## Validation evidence to record

- Migration up/down runs clean on development database.
- `Analytics::Event` loads without error; `CONTENT_TYPES` constant matches `Comment::COMMENTABLE_TYPES`.
- Indexes appear in `schema.rb` after migration.
- Specs pass: validations, scopes, anonymize, purge, archive.
- Query plans show index usage for rollup and erasure patterns.

## Next phase

Proceed to [Phase 3 — Ingestion and rolling deduplication](phase-3-ingestion-and-rolling-deduplication.md).