# Wine Words — First-party content analytics implementation plan

Prepared: 8 October 2026  
Scope: Rails API + React frontend; Wines, Reviews and Articles  
Deliverable: phased implementation specification, acceptance criteria, AI coding prompts and operational documentation requirements.

## 1. Purpose and implementation status

Build an editorial analytics dashboard using one polymorphic `ContentView` event model, existing Likes and Comments, and server-side aggregate queries. Track anonymous and authenticated readership, exclude administrative and self-authored views, and provide useful metrics without introducing unnecessary infrastructure.

Repository targets:

- API: https://github.com/romalopes/wine_words_api
- Frontend: https://github.com/romalopes/wine_words_front_end
- Current frontend: https://wine-words.vercel.app
- Current API: https://wine-words-api.onrender.com

This document is based on the supplied analytics discussion. It does **not** claim that these repositories were inspected for this deliverable. Phase 0 must establish current model names, relationships, roles, libraries and routes before code changes. File paths below are proposed locations; adapt them to verified repository conventions.

Expected initial traffic: approximately 100–1,000 visits/day. Start with lightweight synchronous database ingestion and indexed queries. Do not introduce Sidekiq, Redis, daily rollups or HyperLogLog solely because they may become useful later.

## 2. Locked product rules

| Area | V1 decision |
| --- | --- |
| Trackable content | Wine, Review, Article only |
| Counted view | An accepted detail-page event after successful loading and visibility checks |
| Duplicate rule | At most one accepted event per resource and analytics identity every 30 minutes, measured from the last accepted event |
| Anonymous users | Count when analytics tracking is permitted |
| Admins | Never count, including admins who also have another role |
| Article/Review authors | Do not count their own content views; exclude all verified authors if coauthorship exists |
| Editors | Count unless also Admin or an author of the content |
| Wine creators | Count unless Admin; do not invent Wine ownership exclusions |
| Draft/private preview | Never count preview or draft loads |
| Published restricted content | Count only when the viewer is authorized to read it |
| Comments | Count visible top-level comments and visible replies; expose their breakdown |
| Reviewer analytics | Own Articles and Reviews, plus global Wine analytics |
| Editor analytics | All Wine, Article and Review analytics |
| Admin analytics | All content analytics and site-wide reporting; separate debug permission |
| Guest/Reader analytics | No private dashboard access |
| Failed tracking | Drop the event; no offline queue or automatic retry |
| Storage/reporting | UTC timestamps; Australia/Sydney reporting days |
| Engagement | Interaction rate, not a percentage of people who engaged |
| Identity reconciliation | No anonymous-to-account merging in V1 |
| Conversion | Capture navigation context now; label observed transitions, not proven causal conversions |
| Scaling | Document future rollups; create them only when justified by measurement |

These are product defaults derived from the discussion. The repository audit may reveal terminology differences, but should not silently change these behaviors.

## 3. Metric dictionary

All period filters use one interval: `[start_at, end_at)` in UTC. The inclusive start and exclusive end prevent overlaps between adjacent reporting periods.

| API metric | Definition |
| --- | --- |
| `views` | Accepted ContentView rows with `viewed_at` within the period |
| `unique_viewers` | Distinct `visitor_key` for one resource during the period |
| `unique_visitors` | Distinct `visitor_key` across the authorized resource set during the period |
| `likes` | Currently existing valid Likes created during the period |
| `top_level_comments` | Currently visible top-level Comments created during the period |
| `replies` | Currently visible replies created during the period |
| `comments` | Top-level comments + replies |
| `like_rate` | Period likes / period unique viewers |
| `comment_rate` | Period comments / period unique viewers |
| `engagement_rate` | (Period likes + period comments) / period unique viewers |
| `lifetime_likes` | Existing Likes across all dates, separately labeled |
| `lifetime_comments` | Visible Comments across all dates, separately labeled |

Use the authorized-set `unique_visitors` denominator for overview rates. Never sum per-resource uniques to get a site or scope total. Global Wine uniques can differ from total editorial uniques because identities overlap.

All rates return `0.0` when the denominator is zero. Return numeric decimal values, never NaN or Infinity. A response also exposes `rate_denominator_zero` so the UI can show “No counted viewers” instead of implying a measured zero engagement rate.

**Rates may exceed 100% even with matching periods.** A reader can post multiple comments and like multiple resources. Authors/Admins can contribute interactions while their views are excluded. These are interactions per measured identity, not a bounded conversion rate. Label the UI “Interactions per 100 viewers” where feasible, and explain any retained “Engagement” label in a tooltip. A bounded “engaged visitor percentage” would require distinct participant matching and a different specification.

Existing Like/Comment tables are mutable. An unlike or deleted comment can change historical reports; `created_at` gives the creation period but cannot reconstruct removed activity. V1 reports surviving visible records. Do not promise immutable historical interaction counts. If the audit finds events or audit logs that support historical activity, document them before extending this rule.

## 4. Identity semantics

Send `visitor_id` with every tracking request, including authenticated requests, whenever tracking is allowed. Use a browser-generated random UUID. Do not fingerprint visitors.

The API derives Account identity from the existing authentication layer. A client-supplied `account_id` is ignored or rejected.

```ruby
visitor_key = account.present? ? "account:#{account.id}" : "visitor:#{visitor_id}"
```

The server computes and stores this immutable, ingestion-time key. It also stores `visitor_id` and optional `account_id` for operational requirements and possible future reconciliation. Never group solely on `visitor_id` or use unprefixed `COALESCE(account_id::text, visitor_id)`; identifiers require separate namespaces.

Consequences to document and test:

- An account used on two browsers produces one authenticated analytics identity.
- Anonymous browsers/devices remain separate identities.
- Anonymous activity followed by login can count as two identities and two views within 30 minutes. This is an explicit V1 limitation.
- Shared devices can undercount anonymous people; shared accounts can undercount people.
- Clearing local storage or changing browsers can increase distinct counts.
- Device-local anonymous IDs are client asserted, not verified identities.

Dashboard explanatory text: “Approximate browser/account identities; not a count of individual people.”

Storage access must tolerate exceptions. Fall back to an in-memory UUID for the current page lifetime when persistent storage is unavailable, but only if tracking is permitted. If tracking is disabled or consent is withheld, send nothing and do not create the persistent identifier. On account switches, recompute frontend suppression keys using the current authenticated context.

## 5. Privacy and retention product specification

This is an implementation specification, not a determination that one legal basis is valid everywhere. Do not assume that first-party analytics, localStorage, UUIDs or IP hashing automatically remove consent obligations.

Before enabling persistent identifiers in production:

1. Review the actual audience and relevant privacy requirements with the appropriate owner.
2. Document the approved tracking basis and whether consent is required.
3. Implement the agreed consent/opt-out behavior; default persistent tracking to disabled until configured.
4. Provide a clear privacy notice describing the identifier, purposes, recipients, retention and deletion route.

Proposed V1 raw-event retention: **90 days**, configurable. Until rollups exist, “1 year” and “All time” mean **available retained data**, not historical lifetime totals. Return `available_from`, `retention_days` and `is_partial_history`; show the limitation in the dashboard. Do not silently return a full-year label for 90 days of retained views.

Likes/comments remain subject to their existing lifecycle. For retained-window comparisons, constrain the whole comparison to the same available view period. Display any separate lifetime interaction totals explicitly.

Proposed deletion default: delete raw analytics events associated with a deleted Account and delete the account's dedup keys. Nulling `account_id` is insufficient if `visitor_key` still includes the account ID. Support deletion of known visitor UUIDs through a verified browser-based route or operational procedure without exposing another visitor's activity. Do not imply that all anonymous historical activity can always be identified from an account.

No raw IP, full referrer URL, user-agent string, email, name, token or precise location in ContentView. Rate limiting can process request IP transiently through established middleware; keep it out of analytics logs and durable events. Any future hashing requires keyed hashing, rotation, access controls and retention; it is not automatic anonymization.

## 6. Architecture and contracts

Proposed service boundaries:

- `Analytics::Identity`: server-side normalized identity.
- `Analytics::Visibility`: reuse existing readable/published scopes.
- `Analytics::TrackView`: validation, exclusions and ingestion coordination.
- `Analytics::Deduplicator`: transaction-safe exact rolling-window behavior.
- `Analytics::Period`: validated reporting interval and timezone.
- `Analytics::Scope`: authorized resource sets.
- `Analytics::Summary`, `ContentPerformance`, `ContentDetails`, `Trending`.
- `Analytics::WineInsights`: producer/region/grape groupings from existing associations.

Reuse existing policy/service conventions rather than requiring these exact class names.

### Proposed ContentView schema

| Field | Type | Notes |
| --- | --- | --- |
| `id` | Existing primary key convention | |
| `viewable_type` | string, non-null | Exact allowlist, never arbitrary constantization |
| `viewable_id` | bigint or verified key type, non-null | Polymorphic reference |
| `account_id` | verified FK type, nullable | Authentication-derived; Account lifecycle handling required |
| `visitor_id` | UUID, non-null | Validated client browser identifier |
| `visitor_key` | string, non-null | Server computed namespaced key |
| `viewed_at` | timezone-safe timestamp, non-null | Server time; never accept client event times in V1 |
| `source_kind` | string, nullable | Allowlisted `wine`, `review`, `article`, `home`, `search`, etc. |
| `source_id` | verified key type, nullable | Only for resource-bearing source kinds |
| `navigation_id` | UUID, nullable | Client navigation correlation; not identity or proof of authenticity |
| `created_at` | timestamp | Existing timestamp conventions |

Record no title/author/profile snapshots in raw events. Source context is optional and untrusted: validate shape, length, allowlist and resource relationships; discard invalid source metadata without failing otherwise valid tracking.

Recommended initial indexes, finalized against measured query patterns:

- `(viewable_type, viewable_id, viewed_at)` for resource periods.
- `(viewable_type, viewable_id, visitor_key, viewed_at)` for rolling-window lookup.
- `(viewed_at)` for retention and cross-resource reporting.
- `(account_id)` for account deletion if needed and not already indexed.
- Add `(viewable_type, viewed_at)` only if EXPLAIN shows benefit.

Add type constraints and request-level positive/valid ID checks. Polymorphic associations do not provide ordinary cross-table foreign keys: visibility lookup and deletion handling must be explicit. Do not add redundant indexes without evidence.

### Ingestion API

```http
POST /api/v1/analytics/views
Content-Type: application/json
```

```json
{
  "viewable_type": "Review",
  "viewable_id": 123,
  "visitor_id": "891c1f4e-01e1-4897-9777-566fd1d59b8b",
  "source_kind": "wine",
  "source_id": 23,
  "navigation_id": "c9c76853-4025-4843-b5a9-28a448382cb7"
}
```

Public success responses should use a consistent neutral shape, such as `{"accepted":true}`, for counted and intentionally ignored valid events. This means “request processed,” not “human view verified.” Avoid exposing whether the visitor is an owner/Admin. Detailed reasons belong in bounded internal diagnostics. Use existing API conventions for invalid payloads, unauthorized/unavailable content, rate limits and unavailable ingestion.

Authenticate when credentials are present; malformed/expired credentials must not silently become anonymous to bypass Admin/owner exclusions. Missing credentials may be legitimately anonymous. A logged-out Admin cannot reliably be identified and excluded; document this limitation.

### Reporting API

```http
GET /api/v1/analytics/summary
GET /api/v1/analytics/content
GET /api/v1/analytics/content/:type/:id
GET /api/v1/analytics/trending
GET /api/v1/analytics/wine-insights
GET /api/v1/analytics/debug/events
```

Example filters: `type=review`, `period=30d`, `sort=views`, `direction=desc`, `page=1`, `per_page=25`. Custom ranges use ISO dates interpreted in the reporting timezone. Allowlist all types, sort columns, direction, grouping and period tokens; cap pagination and custom-range lengths. Never interpolate unchecked parameters into SQL.

Include metadata: effective UTC boundaries, reporting timezone, metric definition version, available history, scope label, pagination and completeness. Reviewer summaries are named **Your editorial content + global Wines**, never “Site-wide.” Scope every endpoint, chart, ranking, breakdown and total before aggregation.

## 7. Atomic rolling-window deduplication

Fixed half-hour buckets do not enforce a rolling 30-minute rule: 10:29:59 and 10:30:01 fall in different buckets. Frontend guards and `exists?` followed by `create!` without serialization are also insufficient.

### Recommended V1: PostgreSQL transaction-level advisory lock

This is a recommendation for Wine Words' expected scale, not an assertion about existing infrastructure. It avoids requiring another service and commits dedup decisions with the accepted event.

1. Start a short transaction using one database connection.
2. Derive a stable signed 64-bit lock key from namespaced `(type, id, visitor_key)`. Do not use Ruby's process-randomized `hash`.
3. Acquire `pg_advisory_xact_lock` using parameterized SQL inside that transaction.
4. After acquiring the lock, obtain the current timestamp and check the newest accepted event for the same tuple.
5. If `last_viewed_at > now - window`, ignore. At exactly 30 minutes, allow.
6. Otherwise insert ContentView with that server timestamp and commit.
7. Rollback on insert failure; no dedup marker survives without an event.

Use READ COMMITTED behavior and separate lock/read statements so the check observes a preceding committed concurrent event after waiting. Do not implement a combined query whose snapshot predates the lock acquisition. Use bounded lock/statement timeouts, no session-level locks, no network work inside the transaction. A hash collision should only serialize unrelated requests, never cause a false duplicate, because the full tuple is checked.

Verify compatibility with the actual provider/connection pool in integration tests using separate real connections. All ingestion paths must use this service. Requests that hit a timeout or database outage are dropped without affecting page loads.

### Alternative when a suitable shared Redis is already present

Use atomic `SET key token NX EX 1800`; verify the adapter and timeout behavior. `Rails.cache.write(... unless_exist: true)` is acceptable only after proving the chosen shared adapter implements the required atomic semantics. MemoryStore, per-instance caches and unverified cache adapters are insufficient.

A Redis reservation and a PostgreSQL insert are not one transaction. A process crash after reservation but before insert loses the view for the TTL; cache eviction/restart can permit extra views. Use ownership-token comparison for safe release on known insert failure; never unconditionally delete a key another request could own. Document these approximate failure semantics. If exact database-backed behavior is required, use the PostgreSQL approach.

Do not add both implementations to V1 just for flexibility. Audit infrastructure, choose one, document the decision, and test concurrency and the half-hour boundary.

## 8. Phased implementation

For every phase: use a focused branch/PR, list files changed, run relevant existing checks, update documentation, and report remaining limitations. Each prompt below can be pasted into an AI coding tool with both repositories available.

### Phase 0 — Repository audit and implementation map

**Work:** Confirm real models/authentication, roles, authorship, visibility, Likes, Comments/replies, deletion, dashboard routes, chart libraries, timezone, tests, DB/cache/connection pooling and deployment setup. Review AGENTS.md and repository contribution instructions. Identify existing/pending roles-permissions work and integrate analytics capabilities with it.

**Output:** `docs/analytics/repository-audit.md`, proposed change map and architecture decision records. List branch/commit inspected and facts that remain unverified. No feature implementation yet.

**Acceptance:** Every ownership/visibility/policy association has a real reference. No inferred Wine owner. Account/User differences and existing role semantics are explicitly mapped.

```text
Audit wine_words_api and wine_words_front_end for the attached analytics plan.
Inspect repository instructions first. Do not implement feature code yet.
Map actual Wine/Review/Article models, Account/User authentication, authorship
including coauthors, roles/permissions, publication/readability rules, Likes,
Comments/replies, deletion and retention, dashboard/UI conventions, test tools,
cache adapters, PostgreSQL provider/pooling and deployment settings.
Record exact paths and the commits inspected. Flag absent features and conflicts.
Recommend one atomic dedup strategy: PostgreSQL transaction advisory lock unless
an existing shared Redis materially supports a justified alternative.
Write docs/analytics/repository-audit.md and a dependency-ordered implementation
map. Do not invent model fields, policies or endpoints from memory.
```

### Phase 1 — Metrics, identity, permissions and privacy contract

**Work:** Convert sections 2–5 into project documentation and fixtures. Confirm period semantics, reply visibility, mutable Like/Comment behavior, permissions and partial-history labels. Define consent mode and account/visitor deletion behavior.

**Output:** `docs/analytics/metric-dictionary.md`, `identity-and-privacy.md`, `permissions.md`, and ADRs for identity, dedup and retention.

**Acceptance:** Rate definitions allow >100%; zero denominator is handled; no period/lifetime mixing; no implicit anonymous-login merge; Reviewer Wine access is explicit.

```text
Write the analytics contracts before implementation, using the verified audit.
Define accepted views, resource unique viewers, authorized-set unique visitors,
period surviving Likes and visible Comments/replies, zero denominators and
interaction rates that can exceed 100%. Define [start,end) boundaries in UTC
from Australia/Sydney reporting dates. Lock identity to account:<id> otherwise
visitor:<uuid>; send visitor_id for both, with no V1 merge on login.
Map Reviewer own editorial + global Wines, Editor all editorial/Wines and Admin
site-wide access into existing permissions. No dashboard access for Readers.
Document 90-day proposed raw retention, partial-history labels, consent/opt-out,
account/visitor erasure and mutable interaction history limitations.
Implement no assumption of legally sufficient consent or anonymization.
Create fixtures/examples that subsequent tests can reuse.
```

### Phase 2 — Schema and lifecycle foundations

**Work:** Add ContentView with constraints/indexes and verified associations. Implement content/account lifecycle defaults and migration rollback. Soft-deleted content retains raw events only within retention; Admin historical queries may include it. Hard-deleted content deletes associated raw events in V1; do not retain orphan pointers. Preserving anonymized historical totals is a future rollup capability, not a promise of V1.

**Acceptance:** Migration runs and reverses in development; unknown types cannot persist; deleting an account removes namespaced keys; existing editorial behavior remains valid.

```text
Implement ContentView using the audited key types and Rails conventions.
Add viewable_type/id, optional account_id, UUID visitor_id, server visitor_key,
server viewed_at, nullable allowlisted source_kind/source_id and navigation_id.
Add only justified composite indexes and constraints. Do not create rollup or
identity-alias tables. Implement account erasure and verified soft/hard content
lifecycle rules from the plan; no accidental dependent:destroy on soft archive.
Prevent orphan polymorphic raw events on hard deletion. Include migration
rollback and lifecycle tests. Report any schema change requiring a different
product decision rather than inventing associations.
```

### Phase 3 — Ingestion service and concurrency correctness

**Work:** Build Identity, TrackView and one dedup mechanism. Validate/readability-check content, exclude Admins/authors, perform atomic dedup, assign server time. Window configuration defaults to 1,800 seconds and is bounded; changing it changes behavior for retained events and must be documented.

**Acceptance:** Two simultaneous valid requests yield one row. Views two seconds apart across a fixed-bucket boundary yield one row. Suppressed requests do not extend the accepted-view window. An insert failure does not leave a durable dedup decision in the PostgreSQL design.

```text
Implement Analytics::Identity, TrackView and the selected Deduplicator using the
verified audit and contracts. Server authentication determines Account; never
trust account_id or visitor_key from the client. Exclude Admins and all verified
Article/Review authors, including coauthors where present. Editors count unless
excluded; Wine creators count. Validate readable published content first.
For PostgreSQL use a short READ COMMITTED transaction, stable signed 64-bit
namespaced advisory transaction lock, then a separate recent-event read and
insert on the same connection. Acquire current time after the lock. Permit
exactly-window elapsed; duplicates do not move the window. Bound timeouts.
Test with distinct actual DB connections, not only mocks or sequential calls.
Test rollback, collision-safe tuple checks and no lock leakage through pooling.
Do not use fixed buckets or an unprotected check-then-insert.
```

### Phase 4 — HTTP endpoint, abuse controls and authentication

**Work:** Add tracking endpoint, optional authentication, payload limits, allowlists, UUID validation, visibility reuse, rate limiting and bot filtering. Start configurable limits as tuning defaults, not universal safe values: e.g. 60 tracking requests/minute per authenticated Account and 300/minute per trusted client IP; supplement anonymous visitor limits but never rely solely on UUIDs. Shared rate-limit state is necessary across instances; audit existing middleware/shared stores or document the single-instance limitation before rollout.

Use a maintained existing bot detector or a small reviewed crawler denylist. Do not categorically classify every headless browser as fraudulent; controlled tests and legitimate automation may use one. User-agent detection is bypassable and cannot prove humanity. Resolve client IP only through trusted proxy configuration.

For cookie authentication, apply existing CSRF controls; CORS is not CSRF protection. For bearer authentication, preserve Authorization handling. Do not add a secret to public React code.

**Acceptance:** Drafts/private inaccessible content, arbitrary constants, bogus UUIDs, oversized payloads and expired supplied credentials cannot be counted. Authentication exclusions work across real frontend/API origins. Throttling returns the established 429 response.

```text
Add POST /api/v1/analytics/views using existing API conventions.
Support absent credentials as anonymous; reject invalid supplied credentials.
Enforce type/ID/UUID/payload limits and published-readable scopes before ingestion.
Use existing authorization and trusted proxy rules. Add configurable account/IP
rate limits with the audited shared backing store, plus obvious-crawler filtering.
Verify cookie-auth CSRF or bearer-auth headers as applicable, including CORS
preflight for Vercel->Render. Never treat CORS as anti-spoofing.
Return neutral valid processing responses; keep exclusion reasons internal.
No client secrets, arbitrary constantize, raw IP logging or hard dependency on
tracking success for a content response. Test security and rate limits.
```

### Phase 5 — Frontend identity and reliable non-blocking tracking

**Work:** Add `src/services/analytics.ts` and `src/hooks/useTrackView.ts`, adapting to existing architecture. Gate on permission/consent and successful page load, not preview/list cards. Use asynchronous `fetch` with `keepalive: true` and existing auth headers. Beacon cannot set an Authorization header and is therefore inappropriate as a universal replacement. Test cross-origin/preflight behavior.

Use a bounded module-level in-flight/recent-attempt cache keyed by resource + effective authentication context. It must survive StrictMode effect recreation; `useRef` alone is not sufficient across every remount/navigation. Include monotonic timestamps for frontend suppression; clear/expire entries and handle account switches. The backend remains authoritative. Suppress automatic retries after failed requests; allow a genuine later navigation attempt according to the documented window.

**Acceptance:** StrictMode, rerenders, route changes, failed loads, unavailable storage, consent withdrawal and logout/login are tested. Content UI never waits for analytics and shows no tracking failure toast.

```text
Implement reusable analytics service and useTrackView for Wine/Review/Article
using existing HTTP/auth hooks. Send visitor UUID for anonymous and authenticated
views only when tracking is allowed. Handle throwing/disabled localStorage with
an in-memory fallback; no fingerprinting. Gate on successful readable detail
loads and exclude preview routes. Use fetch keepalive with correct auth/CORS.
Use a bounded module-level in-flight/recent-attempt guard plus component guards
as needed; useRef alone is not the correctness mechanism. Include auth identity
in suppression keys and account-switch behavior. Backend dedup stays authoritative.
Drop failed requests without retry/offline queue; do not block navigation or
surface analytics errors to readers. Integrate all three actual detail pages.
Test StrictMode remounts, rerenders, navigation, loading errors, storage failures,
consent changes, authenticated owner exclusions and switching accounts.
```

### Phase 6 — Reporting periods and authorization scopes

**Work:** Implement Period/Scope with role-aware resource sets. Use existing policy framework; do not add Pundit/CanCan solely for analytics if another mechanism exists. Prefer permissions such as `analytics.read_own_editorial`, `read_wines`, `read_all_editorial`, `read_site`, `debug` mapped to current roles. If RBAC refactor is incomplete, integrate current rules behind one boundary and document later mapping.

**Acceptance:** Reviewer cannot request another author's metrics through direct IDs, author filters, summary, ranking, source breakdown or totals. Unauthorized detail returns 404. Site-wide endpoint unavailable to Editor unless explicitly granted site-wide permission.

```text
Implement Analytics::Period and authorization scopes using existing policies.
Use explicit Australia/Sydney date boundaries converted to UTC, [start,end),
including DST and custom ranges. Clamp effective view ranges to available history
and expose partial coverage metadata. Validate and cap every query parameter.
Reviewer sees own Reviews/Articles and all readable Wine analytics; Editor sees
all permitted editorial and Wine content; Admin sees site-wide and archived data
per policy. Guest/Reader denied. Scope before aggregation on every query path.
Return 404 for unauthorized resource details. Include tests for malicious author
filters, mixed-type summaries/rankings, archived content and direct-ID access.
```

### Phase 7 — Database aggregation services and reporting endpoints

**Work:** Build Summary, ContentPerformance and ContentDetails. Aggregate each metric by resource before joining result sets; avoid multiplicative joins across raw views, Likes and Comments. Include authorized published content with zero views by starting from the resource set and left-joining grouped metrics. Author filtering must follow verified associations.

Do not load raw events into Ruby/React to count. Use SQL DISTINCT for period uniques. Support stable ordering with type/id tie-breakers, validated sorting and bounded pagination. Return metadata and metrics without raw identities.

**Acceptance:** Multi-view/multi-like/multi-comment fixtures have exact expected totals; no join inflation; site uniques distinct across resources; zero-view resources appear; query count stays bounded as rows increase.

```text
Implement Summary, ContentPerformance and ContentDetails plus reporting endpoints.
Use the authorized scopes and Period service. Compute period metrics in SQL from
ContentView and existing Like/Comment tables, including visible replies.
Preaggregate each metric before joining to prevent views*likes*comments inflation.
Include authorized zero-view content, distinct scope-level visitor keys, safe
rate calculations and partial-history metadata. Existing interactions are not
copied into analytics tables. Paginate and sort with safe allowlists and stable
resource tie-breakers. Batch authors/titles/associations to avoid N+1 queries.
Test exact numeric fixtures, cross-content overlap, zero denominators, mutable
unlikes/deletions, unauthorized IDs and bounded query count. Measure EXPLAIN
against realistic staging-scale data before adding indexes.
```

### Phase 8 — Dashboard overview and content performance tables

**Work:** Extend the existing dashboard at a verified route such as `/dashboard/analytics`. Tabs: Overview, Wines, Reviews, Articles. Filters: 7d, 30d, 90d, 1y, available history, custom. Date labels show effective coverage.

Overview: views, approximate unique visitors, likes, total discussion, interactions per 100 visitors; chart toggle for views/uniques/likes/comments. Chart uniques are independently computed per day and never summed to make the summary card. Use an existing maintained chart library or audit a lightweight choice; no paid editor/analytics service required.

Table: content/type/author/publication date/views/unique viewers/likes/comments/interaction rate. Numeric/date columns sortable; text sort where supported; pagination/filter state reflected in URL. Show loading, empty, error and partial-history states; accessible chart alternatives and responsive tables/cards.

**Acceptance:** Role-specific labels and hidden tabs correspond to backend permissions; custom query manipulation gains no extra data. Filters consistently update cards/chart/table. Low-traffic and incomplete-history labels remain visible.

```text
Build the Analytics area within the actual dashboard and design system.
Add Overview/Wines/Reviews/Articles, validated date controls, role-aware scope
labels, summary cards, daily chart and sortable paginated performance tables.
Use backend aggregates only. Daily chart uniques cannot be summed for period
uniques. Display approximate identity and retention/partial-history explanations,
zero-denominator state and interaction-rate semantics. Reviewer sees own editorial
content plus global Wines, never a misleading site-wide summary.
Persist relevant filter state in URL. Cover loading, empty, API failure, mobile,
keyboard navigation and accessible chart/table alternatives. Reuse chart/UI
libraries already present where suitable. Add focused component/integration tests.
```

### Phase 9 — Content details, rankings and trending

**Work:** Detail analytics route per type/id, metrics/time series, link to content. Rankings: most viewed, liked, discussed, trending. Trending uses the last seven reporting days in the selected reporting timezone.

Proposed V1 score: `views_7d + 3*likes_7d + 5*comments_7d`, with at least five distinct measured viewers in the seven-day window. Weights/minimum configurable and documented. No minimum age required initially; new content may trend once activity qualifies. Break ties by recent views, publication date, type/id. Show “Not enough activity” when no items qualify rather than relaxing thresholds silently. It is an activity ranking, not an engagement percentage or growth estimator.

**Acceptance:** Old all-time hits do not dominate purely from lifetime totals; Reviewer trending follows scopes; insufficient-activity content excluded; formulas match documented examples.

```text
Implement authorized content detail analytics and most-viewed/liked/discussed
rankings. Add Trending with the documented 7-day score: views + 3*likes + 5*comments,
minimum five distinct viewers, configurable weights/threshold and deterministic
ties. Do not substitute all-time totals or engagement percentages.
Add time-series chart, comment/reply breakdown, effective date/coverage labels,
and links back to readable content. Empty trending results stay empty with a
clear explanation. Test role scopes, thresholds, new/old content and numeric
score examples. No raw visitor identities in editorial views.
```

### Phase 10 — Wine intelligence and navigation context

**Work:** Wine rows include period views/uniques/interactions and separately labeled visible Review count. Review count is a current relationship count, not a view-period activity unless explicitly filtered by publication date.

Group Wine views through existing producer/region/grape relationships. A Wine with two grapes contributes its views to both grape categories. These categories overlap and totals are not additive; document this and do not use a misleading pie chart. Deduplicate duplicate association rows and compute group distinct identities across Wines. No creation of missing domain relationships.

Capture router navigation source when a real Wine->Review click occurs; validate Review belongs to Wine. Do not use the HTTP Referer as the sole SPA navigation source or persist arbitrary URLs. Dedup may discard a Review event if it was recently viewed, so ContentView context supports **observed accepted transitions**, not all clicks or a robust conversion funnel. A real funnel later needs separate navigation/click events plus defined session/window/denominator rules.

**Acceptance:** Multi-grape/multi-region associations do not accidentally multiply one category's event count; overlapping group labels shown; direct Review loads are not attributed to Wines; user-submitted attribution remains unverified.

```text
Add WineInsights for verified producer/region/grape associations only.
Aggregate Wine events with correct many-to-many dedup and group-level distinct
identities. State categories overlap; do not imply sums equal site totals.
Expose current visible Review count separately from period activity metrics.
Link to existing readable Wine/Producer/Region/Grape pages.
Carry allowlisted navigation context on Wine->Review clicks and validate the
relationship server-side. Direct loads have no inferred source. Label context
as observed accepted transitions; do not claim click or conversion accuracy
from deduplicated ContentView events. Document the separate-event/session design
needed for a future funnel and test multi-association and attribution edge cases.
```

### Phase 11 — Operational diagnostics, retention and erasure

**Work:** Provide permission-protected, bounded accepted-event debug data: timestamps/type/id, masked opaque identity display if required. Prefer counts and exclusion reason counters. No full UUID/account keys in general logs. Rejected requests are not saved as analytics events. Logs cannot become a shadow indefinite-retention dataset.

Add retention cleanup command/job, idempotent bounded batches, dry-run mode and scheduler guidance. Reuse existing scheduler/job infrastructure; creating a full queue for this is unnecessary. Add account/visitor erasure workflow with access controls and safeguards; these operations are irreversible and must follow project operational authorization policies.

**Acceptance:** Debug access is Admin + explicit permission, paginated/capped; raw event inspection disabled by default in production. Cleanup removes events older than cutoff without large locks; missing scheduler is observable. Erasure clears both events and any related caches without preserving account identifiers in visitor keys.

```text
Implement bounded Admin-only analytics diagnostics with explicit debug permission
and production feature flag. Show accepted event timing/type/resource with masked
identities only when needed. Use aggregate exclusion counters for ignored requests;
do not store rejected events or raw IPs, tokens, names or full user-agent strings.
Implement configurable raw retention cleanup in small idempotent batches with
an operational dry-run command. Integrate the existing scheduler or document an
external scheduled invocation; no queue introduced solely for analytics.
Implement verified account/known-visitor erasure and dedup-cache cleanup if used.
Test retention boundary, repeated runs, account deletion, permissions and masked
logs. Update privacy documentation and available-history responses.
```

### Phase 12 — Security, performance and end-to-end verification

**Work:** Exercise frontend/API together against staging, realistic event datasets and real DB concurrency. Run repository-mandated checks using detected tools. Test CORS on actual configured origins and both anonymous/auth flows. Benchmark Summary/content/detail/wine insights and report query plans, memory and latency. Set agreed staging targets; proposed dashboard API p95 target under 500 ms at representative data size, then tune based on measured hosting behavior. Do not mistake sleeping-instance cold start for SQL execution latency.

**Acceptance:** All required checks pass; no authorization leaks, join inflation or concurrency double counts. Analytics outage leaves content readable. No unnecessary worker/service or memory-heavy record loading added to the Render API.

```text
Audit and test the completed analytics feature in both repositories.
Run required backend/frontend checks and staging E2E with real auth/origins.
Verify admin/self-author exclusions, anonymous/login approximation, readable
published-only tracking, bot/rate limits, optional-auth failures, UUID/type/input
validation, CSRF where applicable, exact rolling concurrency and bucket-boundary
behavior, StrictMode/navigation and tracking outage isolation.
Verify Reviewer/Editor/Admin scopes on summary/table/details/trending/insights,
DST dates, unique counts, replies, zero rates, >100% interaction rates, overlapping
Wine categories, erasure and retention coverage labels.
Benchmark queries with realistic seeded data; report bounded query counts,
EXPLAIN plans, latency and memory. Fix measured regressions and rerun affected
checks. Report passed/failed checks and unresolved limits honestly; no invented
live validation or test results.
```

### Phase 13 — Deployment, rollback and operating guide

**Work:** Generate actual commands from each repository's scripts and versions. Proposed documentation: `docs/analytics/operations.md` and `docs/analytics/api.md`. Include setup, migrations, tests, configuration, consent controls, feature flags, rate-limit backing store, diagnostics, maintenance, backup/rollback, metrics and troubleshooting.

Suggested feature controls (names proposed, wire and document actual implementation):

| Configuration | Default/purpose |
| --- | --- |
| `ANALYTICS_TRACKING_ENABLED` | false until staged validation and privacy configuration |
| `ANALYTICS_DASHBOARD_ENABLED` | false until reporting validation |
| `ANALYTICS_DEDUP_WINDOW_SECONDS` | 1800 |
| `ANALYTICS_REPORTING_TIMEZONE` | Australia/Sydney |
| `ANALYTICS_RAW_RETENTION_DAYS` | 90 |
| `ANALYTICS_DEBUG_ENABLED` | false in production |
| Trending weights/minimum | 1/3/5 and 5 viewers |
| Frontend tracking flag | Must match effective consent/permissions; not a security boundary |

Deploy order: additive API migration and disabled-compatible API -> backend smoke tests -> frontend build -> authenticated/anonymous staged validation -> privacy notice/consent configuration -> enable tracking -> observe -> enable dashboard. Vite environment changes require a frontend rebuild; server controls remain authoritative.

Rollback: disable tracking/dashboard, revert application versions while retaining additive data schema, confirm content still works. Avoid destructive down migrations in production as the routine rollback. Restoring a database backup requires existing documented procedures and authorized execution; this plan does not run restores.

**Acceptance:** A developer can run every documented command and understand prerequisites, effect, expected output, failure cases and reversal. API/dashboard failure can be isolated without redeploying unrelated content functionality.

```text
Write docs/analytics/operations.md and api.md with verified commands from the
actual repositories. Include local/staging setup, migration/test/build/lint,
environment variables, optional cache configuration, consent/feature controls,
scheduler/retention dry-run and execution, safe erasure, API payload examples,
permissions, metrics, scope/retention labels and common troubleshooting.
For each command explain where to run it, prerequisites, what it changes,
expected output, risks and rollback. Never expose real tokens or production
credentials. Document Vite rebuild requirements and CORS/auth behavior.
Provide additive deploy order, staged smoke checklist, monitoring and reversible
feature disable rollback. Do not purchase services or deploy/change live accounts
unless separately authorized. Summarize release readiness with real evidence.
```

### Phase 14 — Future scaling design, without unused infrastructure

**Triggers:** Sustained dashboard query latency above agreed target, significant event-table growth, ingestion connection contention or memory pressure. First analyze indexes, ranges, pagination and SQL plans; use scoped caching with correct invalidation only if measured benefit warrants it. Cache keys must include authorization scope, author filters, period, timezone and definition version.

Future additive daily rollup design: date/reporting timezone, resource type/id, metric definition version, views, likes, top-level comments, replies, update watermark. Mark interaction counts as mutable snapshots unless a dedicated event ledger is introduced. Only additive totals can be summed; daily unique counts cannot produce period unique counts.

For exact recent uniques retain raw events; for long-range distinct introduce a deliberately selected mergeable approximate structure such as HLL if supported, with accuracy/privacy/delete limitations. After raw pruning, account/visitor erasure from approximate sketches may not be feasible; address that before adopting them. Preserve coverage metadata when neither exact nor approximate uniques are available.

A future longer history requires rollups/backfill while raw events still exist. No retrospective recreation of erased data. Do not claim that 1-year exact unique visitors are available from 90-day raw storage.

Only consider batch/background ingestion after measured write pressure. It requires idempotency, delivery semantics, queue capacity, backpressure and dropped-event observability. It is a separate design phase.

```text
Write docs/analytics/scaling-roadmap.md from measured performance evidence.
Do not create unused tables/services. Describe triggers for query tuning, scoped
cache, daily rollups, approximate distinct counts and eventual batch ingestion.
Design versioned daily additive metrics and watermark/backfill/recompute behavior,
including mutable Like/Comment history. Never sum daily uniques for period totals.
Explain raw-retention limits, long-range history coverage and HLL deletion/accuracy
constraints. Define authorization-aware cache keys. Identify next measurements
before recommending Redis, workers, paid infrastructure or new extensions.
```

## 9. Consolidated verification matrix

| Scenario | Expected behavior |
| --- | --- |
| Anonymous valid published detail | One accepted row when tracking permitted |
| Reader detail view | Counted with server-derived Account identity |
| Reviewer reads another author's content | Counted; cannot read that author's private analytics |
| Owner/coauthor reads own Article/Review | No accepted row |
| Admin also has Reviewer role | No accepted row |
| Editor reads another author's content | Counted |
| Wine creator who is not Admin | Counted |
| Draft/preview/inaccessible content | No accepted row |
| Published paywalled content, entitled user | Counted |
| Expired supplied bearer token | Existing authentication error; no anonymous fallback |
| Two simultaneous same-tuple requests | One accepted row |
| Two seconds across a half-hour boundary | One accepted row |
| Exactly 30 minutes after last accepted row | New accepted row |
| Repeated ignored requests | Window remains based on last accepted row |
| Same anonymous browser then login | May count twice; documented V1 approximation |
| Authenticated account on two devices | Shared Account identity for dedup and distinct |
| Two distinct resources, same identity | Two views, one authorized-set unique visitor |
| Multiple views/likes/comments join | Correct totals; no Cartesian multiplication |
| Multiple replies by one viewer | Interaction rate may exceed 100% |
| Zero measured viewers with interactions | Rate 0.0 plus denominator-zero flag |
| Unlike or comment removal | Surviving-record historic count may change |
| DST transition/report end boundary | Correct local days and [start,end) UTC bounds |
| Reviewer changes resource/author query | No unauthorized aggregate or detail exposure |
| Wine assigned two grapes | Each relevant category credited; totals labeled overlapping |
| Direct Review URL without Wine navigation | No Wine->Review attribution inferred |
| Recent duplicate Review click from Wine | No claim that all clicks/funnel transitions were captured |
| StrictMode/rerender/remount | Client request suppression; backend guarantees counted rows |
| Consent withheld/withdrawn | No tracking; persistent ID cleared per approved policy |
| localStorage unavailable | Allowed in-memory fallback; content still works |
| DB/cache/tracking endpoint unavailable | Page remains usable; analytics dropped |
| Account erasure | Associated events/keys removed; no account key left behind |
| Content archive | Raw events retained within retention and policy scopes |
| Hard content deletion | Raw references removed; no promised historical totals in V1 |
| 1-year query with 90-day retained data | Effective range and partial-history label shown |
| Cleanup executed twice | Safe, bounded and idempotent |

## 10. Release checklist and definition of done

- [ ] Audit references actual code and commit identifiers in both repositories.
- [ ] Metric/identity/privacy/permission contracts are implemented and documented.
- [ ] Consent configuration and privacy notice are ready before persistent tracking is enabled.
- [ ] All three detail pages track after successful authorized loads.
- [ ] Atomic 30-minute dedup passes real concurrent-connection tests.
- [ ] Admin/authorship/visibility exclusions and anonymous authentication rules pass.
- [ ] All reporting paths enforce authorized scopes in Rails before aggregating.
- [ ] Period likes/comments, reply semantics and distinct identities are correct.
- [ ] Rates and available-history coverage are honestly labeled.
- [ ] Responsive/accessible overview, tables, details, rankings and Wine insights work.
- [ ] Navigation-source metadata is limited and not represented as a proven conversion funnel.
- [ ] Cleanup scheduling, deletion, masked diagnostics and incident controls are verified.
- [ ] Representative SQL performance and Render memory use are measured.
- [ ] Required backend/frontend checks and staging E2E pass.
- [ ] Operating/API/scaling guides contain verified commands and failure/rollback guidance.
- [ ] Production rollout has reversible feature controls and documented observation criteria.

## 11. Master AI prompt

```text
Implement the attached Wine Words first-party analytics plan across
wine_words_api and wine_words_front_end, one phase at a time.
Start with Phase 0 and inspect AGENTS.md/current code. Treat every proposed path
and relationship as unverified until audited. Follow existing auth, service,
serialization, authorization, UI and test conventions. Preserve existing behavior.
Use one polymorphic ContentView for Wine/Review/Article. Existing Likes and
Comments remain their own source of truth. Enforce the formal metric, identity,
visibility, authorship, privacy/retention and permission contracts in this plan.
Prioritize transaction-safe rolling dedup, bounded SQL aggregates and lightweight
ingestion appropriate to the actual traffic. No unneeded Redis/Sidekiq/HLL/rollups.
For each phase report files changed, real checks run/results, acceptance coverage,
assumptions and unresolved limitations. Update the specified docs. Do not claim
live validation that was not performed. Do not deploy or change external accounts
unless instructed. Finish with concrete release/rollback and operation guidance.
```

## 12. Technical references

These references inform the mechanism choices; the audit must still verify compatibility with installed versions and deployment configuration.

- PostgreSQL advisory-lock behavior and transaction scope: https://www.postgresql.org/docs/18/explicit-locking.html#ADVISORY-LOCKS
- PostgreSQL advisory-lock functions: https://www.postgresql.org/docs/15/functions-admin.html#FUNCTIONS-ADVISORY-LOCKS
- Redis atomic SET options, including NX and expiration: https://redis.io/docs/latest/commands/set/
- W3C Beacon specification and restrictions on request customization: https://www.w3.org/TR/beacon/
- MDN fetch keepalive behavior: https://developer.mozilla.org/en-US/docs/Web/API/Request/keepalive

The PostgreSQL-first recommendation is an architectural judgment for this project. The references describe mechanisms, not the repository's existing configuration or compliance status.
