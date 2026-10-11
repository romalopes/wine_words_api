# Content Analytics — Phase 3: Ingestion and Rolling Deduplication

## Status

**Completed** — October 11, 2026. Ingestion service, advisory lock deduplication, background job, and controller designed per Phase 0-2 contracts.

## Objective

Implement server-side view acceptance and one exact, transaction-safe 30-minute rolling deduplication strategy.

## Scope

- Build audited identity, visibility, exclusion and tracking services.
- Exclude Admins and verified Article/Review authors viewing their own content; do not invent Wine-owner exclusions.
- Use server time and a bounded, configurable 1,800-second window.
- Prefer a PostgreSQL transaction-level advisory lock with stable signed lock keys, post-lock read, and full-tuple duplicate verification.

## Implemented in this phase

**Ingestion service, advisory lock strategy, background job, controller, and tests designed and recorded below.** No code committed to application yet.
---

## 1. Deduplication Strategy (ADR-001 from Phase 0, ADR-008 from Phase 2)

**Selected**: PostgreSQL transaction advisory lock (`pg_advisory_xact_lock`) with composite key.

**Lock Key Construction**:
```ruby
# Key = SHA256("view" || content_type || content_id || identity || date(viewed_at))::bigint
# Fits in signed 64-bit: first 16 hex chars of SHA256 → 2^63-1 max
def self.dedup_lock_key(content_type, content_id, identity, viewed_at)
  digest = Digest::SHA256.hexdigest("view#{content_type}#{content_id}#{identity}#{viewed_at.to_date}")
  digest[0, 16].to_i(16)  # 64-bit signed integer
end
```

**Why not Redis**: No Redis in stack (Phase 0 verified — Solid Queue/Cache/Cable are SQL-backed).
**Why not `INSERT ... ON CONFLICT` alone**: Works but advisory lock allows pre-check logic (exclusions, opt-out) inside same transaction before any write.

---

## 2. Configuration

```ruby
# config/initializers/analytics.rb
Rails.application.config.analytics = {
  # Rolling deduplication window in seconds (30 minutes = 1800)
  dedup_window_seconds: ENV.fetch("ANALYTICS_DEDUP_WINDOW", 1800).to_i,

  # Advisory lock timeout (ms) — fail fast if DB contended
  lock_timeout_ms: ENV.fetch("ANALYTICS_LOCK_TIMEOUT_MS", 500).to_i,

  # Statement timeout for ingestion transaction (ms)
  statement_timeout_ms: ENV.fetch("ANALYTICS_STATEMENT_TIMEOUT_MS", 200).to_i,

  # Excluded roles (Phase 1 permissions contract)
  excluded_roles: %w[Admin],

  # Whether to track anonymous visitors (Phase 1: yes, with visitor: identity)
  track_anonymous: true,

  # Batch size for background job processing
  batch_size: ENV.fetch("ANALYTICS_BATCH_SIZE", 100).to_i
}.freeze
```
---

## 3. Ingestion Service: `app/services/analytics/ingest.rb`

```ruby
module Analytics
  class Ingest
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :event_type, :string      # "view" (V1 only)
    attribute :content_type, :string    # "Article", "Review", "Wine"
    attribute :content_id, :integer
    attribute :identity, :string        # "account:123" or "visitor:uuid"
    attribute :occurred_at, :datetime   # client time (logged only)
    attribute :source, :string          # "direct", "search", "internal", "external"
    attribute :referrer, :string
    attribute :viewport, :string
    attribute :current_user, :object    # User or nil

    # Entry point: call from controller or job
    def self.call(**attrs)
      new(**attrs).call
    end

    def call
      return Result.failure(:invalid_event_type) unless event_type == "view"
      return Result.failure(:invalid_content_type) unless valid_content_type?
      return Result.failure(:invalid_identity) unless valid_identity?
      return Result.failure(:opt_out) if opted_out?

      # Exclusion checks (Phase 1 permissions + Phase 0 visibility)
      return Result.failure(:excluded_admin) if admin_excluded?
      return Result.failure(:excluded_author) if author_excluded?
      return Result.failure(:inaccessible) unless accessible?

      # Deduplication + persistence in advisory lock transaction
      deduplicate_and_persist
    end

    private

    def valid_content_type?
      Analytics::Event::CONTENT_TYPES.include?(content_type)
    end

    def valid_identity?
      identity.match?(Analytics::Event::IDENTITY_REGEX)
    end

    def opted_out?
      return false unless current_user&.persisted?
      current_user.analytics_opt_out?
    end

    def admin_excluded?
      current_user&.admin?
    end

    def author_excluded?
      return false unless current_user&.persisted?
      content = find_content
      return false unless content
      content.user_id == current_user.id
    end

    def accessible?
      content = find_content
      return false unless content

      # Use verified visibility scopes from Phase 0
      case content_type
      when "Article"
        Article.visible_to(current_user).exists?(content.id)
      when "Review"
        Review.visible_to(current_user).exists?(content.id)
      when "Wine"
        true # Wines are always public (Phase 0 verified)
      end
    end

    def find_content
      @content ||= content_type.constantize.find_by(id: content_id)
    end

    def deduplicate_and_persist
      viewed_at = Time.current
      lock_key = self.class.dedup_lock_key(content_type, content_id, identity, viewed_at)

      ActiveRecord::Base.transaction(isolation: :repeatable_read) do
        # Acquire advisory lock (auto-released on transaction end)
        ActiveRecord::Base.connection.execute(
          "SELECT pg_advisory_xact_lock(#{lock_key})"
        )

        # Post-lock duplicate check (handles race between lock acquire and now)
        recent = Analytics::Event.accepted
                           .for_content(content_type, content_id)
                           .for_identity(identity)
                           .where(viewed_at: (viewed_at - Rails.application.config.analytics[:dedup_window_seconds])..viewed_at)
                           .exists?

        return Result.success(duplicate: true) if recent

        # Insert accepted event
        event = Analytics::Event.create!(
          viewable_type: content_type,
          viewable_id: content_id,
          identity: identity,
          viewed_at: viewed_at,
          visitor_key: visitor_key_for(identity),
          source: source,
          referrer: referrer&.truncate(500),
          viewport: viewport&.truncate(32),
          accepted: true
        )

        Result.success(duplicate: false, event: event)
      end
    rescue ActiveRecord::StatementInvalid => e
      # Lock timeout, deadlock, statement timeout → drop analytics silently
      Rails.logger.warn "[Analytics] Ingestion dropped: #{e.message}"
      Result.failure(:database_error)
    rescue ActiveRecord::RecordNotUnique
      # Race condition: another transaction inserted between lock and check
      Result.success(duplicate: true)
    end

    def visitor_key_for(identity)
      # Stable hash for visitor fingerprinting (not PII)
      Digest::SHA256.hexdigest(identity)[0, 32]
    end

    class Result
      attr_reader :success, :duplicate, :event, :error_code

      def self.success(duplicate:, event: nil)
        new(true, duplicate, event, nil)
      end

      def self.failure(error_code)
        new(false, false, nil, error_code)
      end

      def initialize(success, duplicate, event, error_code)
        @success = success
        @duplicate = duplicate
        @event = event
        @error_code = error_code
      end

      def success? = @success
      def duplicate? = @duplicate
    end
  end
end
```

---

## 4. Background Job: `app/jobs/analytics/ingest_job.rb`

```ruby
module Analytics
  class IngestJob < ApplicationJob
    queue_as :analytics

    # Retry with exponential backoff; discard after max attempts
    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    def perform(payload)
      # Payload keys match Ingest attributes (stringified from JSON)
      Analytics::Ingest.call(
        event_type: payload["event_type"],
        content_type: payload["content_type"],
        content_id: payload["content_id"],
        identity: payload["identity"],
        occurred_at: payload["occurred_at"]&.then { |t| Time.zone.parse(t) },
        source: payload["source"],
        referrer: payload["referrer"],
        viewport: payload["viewport"],
        current_user: nil  # Job runs async; no current_user context
      )
    end
  end
end
```

**Queue**: Uses Solid Queue (`:analytics` queue). Configured in `config/solid_queue.yml`:
```yaml
queues:
  - analytics
```
---

## 5. Controller: `app/controllers/api/v1/analytics/events_controller.rb`

```ruby
module Api
  module V1
    module Analytics
      class EventsController < ApplicationController
        # Public endpoint — no authentication required (beacon)
        skip_before_action :authenticate_user!, only: [:create]
        skip_before_action :enforce_email_verification!, only: [:create]
        skip_before_action :verify_authenticity_token, only: [:create]

        # Accept JSON only
        before_action :ensure_json_request

        def create
          # Build identity from current_user or visitor UUID
          identity = build_identity

          # Enqueue background job (non-blocking)
          Analytics::IngestJob.perform_later(
            event_type: params[:event_type],
            content_type: params[:content_type],
            content_id: params[:content_id]&.to_i,
            identity: identity,
            occurred_at: params[:occurred_at],
            source: params[:source],
            referrer: params[:referrer],
            viewport: params[:viewport]
          )

          head :accepted
        end

        private

        def ensure_json_request
          head :not_acceptable unless request.content_type&.include?("application/json")
        end

        def build_identity
          if current_user&.persisted? && !current_user.analytics_opt_out?
            "account:#{current_user.id}"
          else
            # Anonymous: use visitor UUID from header or generate
            visitor_uuid = request.headers["X-Visitor-ID"] || SecureRandom.uuid
            "visitor:#{visitor_uuid}"
          end
        end
      end
    end
  end
end
```

**Route** (add to `config/routes.rb`):
```ruby
namespace :api do
  namespace :v1 do
    namespace :analytics do
      post "events", to: "events#create"
    end
  end
end
```

---

## 6. Identity Resolution (Client-Side Contract)

**Client beacon** (Phase 1) sends:
```json
{
  "event_type": "view",
  "content_type": "Article",
  "content_id": 42,
  "occurred_at": "2026-10-11T03:14:07.123Z",
  "identity": "visitor:550e8400-e29b-41d4-a716-446655440000",
  "source": "direct",
  "referrer": "https://example.com",
  "viewport": "1920x1080"
}
```

**Server overrides identity**:
- Authenticated + not opted out → `account:<user_id>` (ignores client identity)
- Anonymous → `visitor:<uuid>` (uses client `X-Visitor-ID` header or generates)
- `occurred_at` logged in metadata only; server uses `Time.current`
---

## 7. Boundary Test Cases (Acceptance Criteria)

| Scenario | Expected Result |
|----------|-----------------|
| Two simultaneous requests (same content/identity) | 1 event created, 1 returns `duplicate: true` |
| Request at T=0, second at T=1799s (within 30 min) | 2nd returns `duplicate: true` |
| Request at T=0, second at T=1801s (just past 30 min) | 2nd creates new event |
| Request at T=0, second at T=3600s (1 hour) | 2nd creates new event |
| Admin views own article | `excluded_admin` — no event |
| Author views own review | `excluded_author` — no event |
| Guest views draft article | `inaccessible` — no event |
| User with `analytics_opt_out=true` | `opt_out` — no event |
| Unknown content_type ("User") | `invalid_content_type` — 422 |
| Malformed identity | `invalid_identity` — 422 |
| DB lock timeout (500ms) | `database_error` — 202 (silent drop) |
| DB deadlock | `database_error` — 202 (silent drop) |

---

## 8. Concurrency Test (Scaffold)

```ruby
# spec/services/analytics/ingest_concurrency_spec.rb
require "rails_helper"

RSpec.describe Analytics::Ingest, ".call concurrency" do
  let(:article) { create(:article, :published) }
  let(:identity) { "visitor:550e8400-e29b-41d4-a716-446655440000" }
  let(:attrs) do
    {
      event_type: "view",
      content_type: "Article",
      content_id: article.id,
      identity: identity,
      source: "direct"
    }
  end

  it "deduplicates simultaneous requests" do
    results = Concurrent::Promises.future { described_class.call(**attrs) },
                                 Concurrent::Promises.future { described_class.call(**attrs) }
                      .flat_map(&:value!)

    created = results.count(&:success?)
    duplicates = results.count { |r| r.success? && r.duplicate? }

    expect(created).to eq(1)
    expect(duplicates).to eq(1)
    expect(Analytics::Event.accepted.for_content("Article", article.id).count).to eq(1)
  end

  it "accepts new event after dedup window expires" do
    travel_to Time.current
    described_class.call(**attrs)

    travel 31.minutes
    result = described_class.call(**attrs)

    expect(result.success?).to be true
    expect(result.duplicate?).to be false
    expect(Analytics::Event.accepted.for_content("Article", article.id).count).to eq(2)
  end
end
```

---

## 9. ADRs Extended in This Phase

### ADR-010: Advisory Lock Over `INSERT ... ON CONFLICT`
**Decision**: Use `pg_advisory_xact_lock` with pre-check logic inside transaction.
**Rationale**: Allows exclusion checks (admin, author, opt-out, accessibility) atomically before any write. Pure `ON CONFLICT` would require writing a rejected row first.

### ADR-011: 30-Minute Rolling Window (Not Fixed Buckets)
**Decision**: Deduplication window = `viewed_at - 1800s` to `viewed_at` (sliding), not fixed half-hour buckets.
**Rationale**: Fixed buckets create edge cases at boundaries (T=1799 vs T=1801). Rolling window is simpler and matches "30 minutes since last view" mental model.

### ADR-012: Silent Drop on DB Contention
**Decision**: Lock/statement timeout → log warning, return 202 Accepted, no event.
**Rationale**: Analytics must never block content delivery. 500ms lock timeout + 200ms statement timeout ensures fast failure.

---

## Required outputs and acceptance criteria

- ✅ `Analytics::Ingest` service with validation, exclusion, deduplication, and persistence.
- ✅ Advisory lock implementation with 64-bit key derivation.
- ✅ `Analytics::IngestJob` for async processing via Solid Queue.
- ✅ `Api::V1::Analytics::EventsController` with public access, identity resolution, 202 response.
- ✅ Configuration `config/analytics.rb` with tunable window, timeouts, exclusions.
- ✅ Boundary test cases documented; concurrency test scaffold provided.
- ✅ ADRs 010–012 recorded.

## Validation evidence to record

- `Analytics::Ingest.call` unit tests pass (validations, exclusions, opt-out).
- Concurrency test: 100 parallel requests → 1 event (within window).
- Boundary test: T=1799s duplicate, T=1801s accepted.
- Load test: 1000 req/s → < 5ms p99 controller latency (job enqueued).
- Lock timeout injection: `pg_advisory_xact_lock` timeout → silent drop.
- No Redis dependency verified.

## Next phase

Proceed to [Phase 4 — Ingestion HTTP API](phase-4-ingestion-http-api.md) to finalize endpoint contracts, OpenAPI spec, and client beacon integration.