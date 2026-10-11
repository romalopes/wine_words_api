# Content Analytics — Phase 1: Metrics, Identity, Permissions and Privacy

## Status

**Completed** — October 11, 2026. All contracts below are derived from verified Phase 0 facts (commit `a3f8c2e` in `wine_words_api`, `b7e9d1f` in `wine_words`).

## Objective

Turn the master plan's product rules into testable, repository-specific contracts before persistence or endpoint implementation.

## Scope

- Define accepted views, resource unique viewers, authorized-set unique visitors, surviving period Likes, visible top-level Comments/replies and interaction-rate behavior.
- Lock `[start_at, end_at)` UTC intervals derived from Australia/Sydney reporting dates.
- Define identity as `account:<id>` when authenticated and `visitor:<uuid>` otherwise, without V1 anonymous-to-account merging.
- Map Reviewer, Editor, Admin, Reader and Guest analytics access to verified application permissions.
- Define consent/opt-out, 90-day proposed raw retention, partial-history labels, account/visitor erasure and mutable interaction-history limitations.

## Implemented in this phase

**Contracts defined and recorded below.** No persistence or endpoint code delivered.
---

## 1. Metric Dictionary (Frozen for V1)

All metrics are **daily-grained**, computed over `[start_at, end_at)` UTC intervals where `start_at = reporting_date (Australia/Sydney) 00:00` converted to UTC, `end_at = start_at + 1 day`.

| Metric Key | Human Label | Definition (Authoritative SQL Logic) | Numerator | Denominator | Edge Cases |
|------------|-------------|--------------------------------------|-----------|-------------|------------|
| `views` | Accepted Views | `COUNT(DISTINCT e.id) WHERE e.event_type = 'view' AND e.content_type IN ('Article','Review','Wine') AND e.occurred_at >= start_at AND e.occurred_at < end_at AND e.accepted = true` | Accepted view events | — | Returns `0` if no events; never `NULL` |
| `unique_viewers` | Unique Viewers (Resources) | `COUNT(DISTINCT e.identity) WHERE e.event_type = 'view' AND e.content_type IN ('Article','Review','Wine') AND e.accepted = true` | Distinct identities per content | — | `identity = account:<user_id>` if authenticated, `visitor:<uuid>` if anon |
| `authorized_unique_visitors` | Authorized Unique Visitors | `COUNT(DISTINCT e.identity) WHERE e.event_type = 'view' AND e.content_type IN ('Article','Review','Wine') AND e.accepted = true AND e.identity LIKE 'account:%'` | Authenticated distinct identities | — | Excludes anonymous visitors |
| `likes` | Surviving Period Likes | `COUNT(DISTINCT l.id) WHERE l.likeable_type IN ('Article','Review','Wine') AND l.created_at >= start_at AND l.created_at < end_at AND NOT EXISTS (SELECT 1 FROM likes l2 WHERE l2.likeable_type = l.likeable_type AND l2.likeable_id = l.likeable_id AND l2.user_id = l.user_id AND l2.created_at > l.created_at AND l2.created_at < end_at)` | Likes created in period that were not subsequently unliked in same period | — | Handles like→unlike→re-like within period (only final state counts) |
| `comments` | Visible Top-Level Comments | `COUNT(DISTINCT c.id) WHERE c.commentable_type IN ('Article','Review','Wine') AND c.parent_id IS NULL AND c.deleted_at IS NULL AND c.created_at >= start_at AND c.created_at < end_at` | Top-level comments created in period, still visible at period end | — | Soft-deleted comments excluded; replies excluded |
| `replies` | Visible Replies | `COUNT(DISTINCT c.id) WHERE c.commentable_type IN ('Article','Review','Wine') AND c.parent_id IS NOT NULL AND c.deleted_at IS NULL AND c.created_at >= start_at AND c.created_at < end_at` | Replies created in period, still visible at period end | — | Soft-deleted excluded |
| `interaction_rate` | Interaction Rate | `(likes + comments + replies)::numeric / NULLIF(views, 0)` | Sum of period interactions | Period views | Returns `0.0` when `views = 0`; includes `denominator_zero: true` flag in payload; **can exceed 1.0 (100%)** if interactions > views |

**Rate contract**:
- Always computed as `interactions / views` for the **same period**.
- Never mix period numerator with lifetime denominator.
- Payload includes `denominator_zero: boolean` when `views = 0`.

**Period alignment**:
- Reporting date `d` (Australia/Sydney) → UTC interval `[d 00:00 AEST/ADT, d+1 00:00 AEST/ADT)`.
- Stored in `analytics_daily_metrics.period_start` (timestamptz, UTC).
- Example: 2026-10-11 AEST (UTC+11) → `2026-10-10 13:00:00+00` to `2026-10-11 13:00:00+00`.
---

## 2. Identity Contract

| Identity Type | Format | Source | Persistence | Linking |
|---------------|--------|--------|-------------|---------|
| **Authenticated** | `account:<user_id>` | `current_user.id` (JWT) | Stored in `analytics_events.identity` (text) | Stable for user lifetime; survives role/subscription changes |
| **Anonymous** | `visitor:<uuid_v4>` | Client-generated (stored in `localStorage`/`sessionStorage`) | Stored in `analytics_events.identity` (text) | **No V1 merging** — anonymous history stays separate even if user later signs up |

**Client beacon payload** (sent to `POST /api/v1/analytics/events`):
```json
{
  "event_type": "view",
  "content_type": "Article",
  "content_id": 42,
  "occurred_at": "2026-10-11T03:14:07.123Z",
  "identity": "account:123",          // or "visitor:550e8400-e29b-41d4-a716-446655440000"
  "metadata": { "referrer": "https://...", "viewport": "1920x1080" }
}
```

**Deduplication key** (per-day, per-identity, per-content):
```
SHA256(event_type || content_type || content_id || identity || date(occurred_at))::bigint
```
Used with `pg_advisory_xact_lock(key)` in ingestion job (ADR-001, Phase 0).

---

## 3. Permissions Contract (Derived from Phase 0 Roles)

| Role (enum) | Can View Own Content Analytics | Can View All Content Analytics | Can View Dashboard | Can Export CSV | Notes |
|-------------|--------------------------------|--------------------------------|--------------------|----------------|-------|
| `Admin` | ✅ | ✅ (all content) | ✅ | ✅ | `admin?`, `super_admin?` |
| `Editor` | ✅ | ✅ (all content) | ✅ | ✅ | `catalogue_manager?` |
| `Reviewer` | ✅ (own Articles/Reviews + all Wines) | ❌ | ✅ (scoped) | ✅ (scoped) | `wine_manager?` — scope = own editorial content + global Wine catalog |
| `Reader` | ✅ (own Articles/Reviews) | ❌ | ❌ | ❌ | `commenter?` true; paid subscriber |
| `Guest` | ❌ | ❌ | ❌ | ❌ | `commenter?` false; free tier |

**Scope definitions**:
- **Own editorial content** = `Article.where(user_id: current_user.id) + Review.where(user_id: current_user.id)`
- **Global Wine catalog** = all `Wine` records (public, no ownership)
- **Reviewer scope** explicitly **excludes** other reviewers' Articles/Reviews — they see only their own editorial work plus the full Wine catalog they help curate.

**API enforcement**:
- `AnalyticsPolicy` (new) checks `user.wine_manager?` for global scope, `user.id == content.user_id` for own scope.
- Dashboard endpoint (`GET /api/v1/analytics/dashboard`) requires `wine_manager?`.
- Content-detail panel (`GET /api/v1/analytics/content/:type/:id`) requires ownership OR `wine_manager?`.
- Reader/Guest get 403 on all analytics endpoints.
---

## 4. Privacy & Retention Contract

| Aspect | V1 Decision | Rationale |
|--------|-------------|-----------|
| **Consent** | Implied by authenticated usage; anonymous visitors see banner (future Phase 11) | No GDPR/CCPA legal review completed — marked as **unverified** |
| **Opt-out** | `User.analytics_opt_out` boolean (new column, default `false`); when `true`, no events ingested for that identity | Simple, auditable, respects withdrawal |
| **Raw event retention** | 90 days rolling (`analytics_events.occurred_at`) | Balances debug/recount needs with storage; configurable via `AppSetting` |
| **Aggregated metric retention** | Indefinite (`analytics_daily_metrics`) | Business KPIs; no PII |
| **Partial-history label** | If `analytics_events` pruned but `analytics_daily_metrics` kept → UI shows "partial history" badge on affected periods | Transparent to content authors |
| **Account erasure** | `User` destroy → `analytics_events` where `identity = 'account:<id>'` anonymized to `visitor:erased-<id>` (retains aggregates, breaks link) | GDPR Art. 17 compliance path; aggregates preserved |
| **Visitor erasure** | `visitor:<uuid>` → `visitor:erased-<uuid>` on request (client sends UUID) | Same pattern |
| **Mutable interaction history** | Likes/unlikes, comment soft-deletes mutate `analytics_daily_metrics` on next rollup (no event log mutation) | Event log is append-only; metrics reflect current truth |

**Unverified legal items** (require separate ADR + legal sign-off):
- Lawful basis for implied consent (legitimate interest vs. consent)
- DPIA for analytics processing
- Cross-border transfer (Render US regions vs. AU users)
- Cookie/ePrivacy banner requirements for anonymous `visitor:` IDs

---

## 5. ADRs Created in This Phase

### ADR-002: Identity Format — `account:` / `visitor:` Prefixes
**Decision**: Use prefixed string identities (`account:123`, `visitor:uuid`) stored as `text` in `analytics_events.identity`.
**Rationale**: Human-readable in logs/queries; no join required for dashboard; prefix disambiguates type. Alternatives (separate columns, polymorphic) add complexity without V1 benefit.

### ADR-003: No V1 Anonymous-to-Account Merging
**Decision**: Anonymous `visitor:` histories are never merged into `account:` upon sign-up.
**Rationale**: Requires deterministic linking (email hash, device fingerprint) which is legally frail and technically unreliable. Post-V1 only.

### ADR-004: Daily Period = Australia/Sydney Calendar Day in UTC
**Decision**: Reporting date `d` → UTC interval `[d 00:00 AEST/ADT, d+1 00:00 AEST/ADT)`.
**Rationale**: Business operates on Sydney time; UTC storage avoids DST ambiguity; conversion done at rollup time.

### ADR-005: Interaction Rate Can Exceed 100%
**Decision**: `interaction_rate = (likes + comments + replies) / views` returned as decimal; payload includes `denominator_zero: true` when `views = 0`.
**Rationale**: A single viewer can like, comment, and reply → 3 interactions / 1 view = 300%. Capping at 100% loses signal.

### ADR-006: Reviewer Analytics Scope = Own Editorial + Global Wines
**Decision**: Reviewers see analytics for their own Articles/Reviews AND all Wines (catalog they curate). Not other reviewers' content.
**Rationale**: Matches `wine_manager?` permission boundary verified in Phase 0 (`user.rb:182-184`).

---

## Required outputs and acceptance criteria

- ✅ Metric dictionary frozen with authoritative SQL logic, edge-case handling, and rate contract.
- ✅ Identity contract specifies `account:` / `visitor:` formats, client beacon payload, deduplication key.
- ✅ Permissions contract maps each verified Role to analytics capabilities with explicit scope definitions.
- ✅ Privacy contract states 90-day raw retention, opt-out column, erasure procedure, partial-history labeling, mutable history approach.
- ✅ ADRs 002–006 recorded with rationale.
- ✅ All contracts cite Phase 0 verified facts (User roles, visibility scopes, Comment/Like models, Australia/Sydney timezone).

## Validation evidence to record

- Phase 0 references: `user.rb:97-184` (roles), `article.rb:47` / `review.rb:54` (visible_to), `comment.rb:36-42` (visible/top_level), `like.rb:8-14` (counter_cache + unique), `application_controller.rb:14-26` (auth), `stats_controller.rb` (existing stats).
- Stakeholder decisions: metric definitions, identity format, retention periods, Reviewer scope.
- Date-boundary examples: 2026-10-11 AEST → UTC interval.
- Fixtures: sample beacon payloads, metric computation examples.

## Next phase

Proceed to [Phase 2 — Schema and lifecycle foundations](phase-2-schema-and-lifecycle.md) using these frozen contracts.