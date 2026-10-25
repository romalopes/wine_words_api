# Wine Words — Follow & Notification Propagation Implementation Plan

**Status:** Implemented — all phases complete (Phases 0–8)  
**Date:** 2026-10-23 (plan) · 2026-10-25 (implementation)  
**Repositories:** [Rails API](https://github.com/romalopes/wine_words_api) · [React frontend](https://github.com/romalopes/wine_words_frontend)

> **Implementation note:** Phase 0 audited the live repositories and corrected the
> original assumptions (Review belongs to exactly one Vintage → Wine → Producer;
> Articles also link direct Producers; wine comments are excluded per issue #192;
> the production queue adapter was silently overridden to `:async`). The approved
> design and every phase's outcome are documented under `phases/`:
>
> | Phase | Document | State |
> |---|---|---|
> | 0 — Audit & approved design | `phases/phase-0-repository-audit-and-design.md` | ✅ |
> | 1 — Follow schema & model | `phases/phase-1-follow-schema-and-model.md` | ✅ |
> | 2 — Follow API & authorization | `phases/phase-2-follow-api-and-authorization.md` | ✅ |
> | 3 — Event schema, publishing & reliability | `phases/phase-3-notification-events-and-reliability.md` | ✅ |
> | 4 — Recipient resolution & delivery | `phases/phase-4-recipient-resolution-and-delivery.md` | ✅ |
> | 5 — React Follow UI & Following page | `phases/phase-5-react-follow-ui-and-following-page.md` | ✅ |
> | 6 — Generalized notification UI | `phases/phase-6-notification-ui-and-end-to-end-flows.md` | ✅ |
> | 7 — Performance, rollout & operations | `phases/phase-7-performance-rollout-and-operations.md` | ✅ |
> | 8 — Preferences & email digests | `phases/phase-8-notification-preferences-and-digests.md` | ✅ (included per user request despite the original "deferred" note) |

**Validation summary:** full API suite regression diff vs the `main` baseline shows zero
new failures (44 pre-existing failures unchanged); the React suite shows zero new
failures (4 pre-existing); `tsc -b`, `eslint`, `vite build`, `zeitwerk` conventions and
all 240+ new specs pass.

## 1. Objective and scope

Users can follow four entity types: **Review, Article, Wine, Producer**. A follow subscribes the user to relevant future activity. Follow is a standalone relationship and **must not** be a `ProducerMembership.membership_type`; `follower` must not be reintroduced into producer membership types.

| Follow target | Included activity                                                                                                                                                                              |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Review        | Publication (for followers already eligible), meaningful published updates, new visible comments/replies                                                                                       |
| Article       | Publication (for followers already eligible), meaningful published updates, new visible comments/replies                                                                                       |
| Wine          | Meaningful Wine updates; new and meaningfully updated Vintages; publication/updates/comments on related Reviews and Articles                                                                   |
| Producer      | Meaningful Producer updates; new Wines; new/updated Vintages for its Wines; publication/updates/comments on Reviews and Articles linked directly to the Producer or through its Wines/Vintages |

**Non-goals for first release:** following individual Vintages, following users, social feeds, real-time sockets, recommendation ranking, push notifications, automatic follows of descendants, notification emails for every comment. Optional email digests and granular preferences are a later phase.

## 2. Domain principles

1. **One explicit Follow row per user/target.** Following a Producer does not generate Wine, Vintage, Review, or Article Follow rows. Indirect coverage is computed at event processing time.
2. **Separate subscriptions from events and deliveries.** A Follow is a subscription; an event describes what happened; a user notification/delivery records who was informed and whether it was read/sent.
3. **Only user-visible, meaningful events.** Do not emit notifications for draft edits, analytics counts, cache changes, autosave, background geocoding, internal status fields, or repeated updates to `updated_at`.
4. **Deduplicate by event and recipient.** If a user follows Review + Wine + Producer, generate exactly one in-app notification for the same event.
5. **Respect publication and authorization.** Check visibility at event generation and delivery/read time; avoid revealing private titles or links to unauthorized users.
6. **Do not notify the actor.** Exclude the user who caused the change, unless a future explicit product requirement changes this.
7. **Reliable asynchronous processing.** Persist events transactionally and dispatch via existing Active Job / Solid Queue or equivalent. Retry safely without duplicates.
8. **No notification storm on imports.** Seed/import/backfill operations must suppress, batch, or explicitly opt into publication events.

## 3. Association discovery and relationship rules

**Do not assume** Reviews and Articles have a single `wine_id`, `producer_id`, or `vintage_id`. Phase 0 must inspect the real associations, including join tables and polymorphic references.

Conceptual propagation:

```text
Producer
  └── Wine(s)
       └── Vintage(s)

Review ──> zero/many Wine(s), Vintage(s), and/or Producer(s)
Article ─> zero/many Wine(s), Vintage(s), and/or Producer(s)

Review/Article comment ──> parent Review/Article

Event -> affected followable targets -> distinct follower users -> notifications
```

For a Review/Article event, determine all affected targets:

- The Review/Article itself.
- Every directly linked Wine, plus any Wine implied by a linked Vintage.
- Every directly linked Producer.
- Every Producer associated with any linked Wine or Vintage.
- If associations can be changed, define whether event audiences use pre-change links, post-change links, or both. **Recommended:** for content updates, use post-change public relationships; for link removal, do not notify users who are no longer related. Persist the resolved target IDs in event context if relationship changes between commit and job execution would alter delivery.

For a Vintage event, include its parent Wine and that Wine's Producer(s). For a Wine event, include Wine and associated Producer(s). For a Producer event, include that Producer. The precise cardinalities must match the codebase.

**Follow-time semantics:** Notifications cover events occurring after the Follow was created. Do not backfill old events on follow. If a Follow is removed before event delivery, suppress the notification unless product requirements explicitly say otherwise. A Follow added after the event must not receive historical notifications. Use event occurrence timestamp plus follow creation time and recheck follow existence when processing.

## 4. Data model

### 4.1 `follows`

Proposed Rails migration (adjust migration version to repository):

```ruby
class CreateFollows < ActiveRecord::Migration[8.1]
  def change
    create_table :follows do |t|
      t.references :user, null: false, foreign_key: true
      t.references :followable, polymorphic: true, null: false
      t.timestamps
    end

    add_index :follows,
              [:user_id, :followable_type, :followable_id],
              unique: true,
              name: "index_follows_unique_user_target"
    add_index :follows,
              [:followable_type, :followable_id, :user_id],
              name: "index_follows_target_users"
  end
end
```

Suggested model:

```ruby
class Follow < ApplicationRecord
  FOLLOWABLE_TYPES = %w[Review Article Wine Producer].freeze

  belongs_to :user
  belongs_to :followable, polymorphic: true

  validates :followable_type, inclusion: { in: FOLLOWABLE_TYPES }
  validates :user_id, uniqueness: {
    scope: %i[followable_type followable_id]
  }
end
```

- Add `has_many :follows, dependent: :destroy` to User.
- Add `has_many :follows, as: :followable, dependent: :destroy` to Review, Article, Wine, Producer.
- Database uniqueness is mandatory; Rails validation alone is insufficient for concurrent requests.
- Polymorphic references lack database-enforced target foreign keys; validate allowed types and target existence, and ensure cleanup on deletion. Audit orphaned rows periodically if raw SQL deletes are used.
- Prefer stable model names over renaming polymorphic type strings without migration.

### 4.2 `notification_events` (only if no equivalent exists)

| Column                       | Type            | Notes                                                                                  |
| ---------------------------- | --------------- | -------------------------------------------------------------------------------------- |
| `id`                         | bigint          | Primary key                                                                            |
| `event_type`                 | string          | e.g. `review.published`                                                                |
| `subject_type`, `subject_id` | polymorphic     | Entity where event occurred                                                            |
| `actor_id`                   | bigint nullable | Acting User                                                                            |
| `metadata`                   | jsonb           | Small immutable event snapshot and affected target references; avoid sensitive content |
| `idempotency_key`            | string          | Unique per logical event/source transaction                                            |
| `occurred_at`                | datetime        | Time of source event                                                                   |
| `created_at`, `updated_at`   | datetime        | Rails timestamps                                                                       |

Add a unique index on `idempotency_key`. Avoid recording unbounded text. If an existing domain event/outbox mechanism is available, **reuse it** rather than adding this table.

### 4.3 User notifications

**Reuse the existing Wine Words notification model, table, controller, unread count, and frontend UI where possible.** Confirm whether it supports polymorphic subjects and actor, per-user read state, links, and event IDs. If not, migrate it minimally.

Required logical attributes: `user_id`, `notification_event_id`, `read_at`, `created_at`, optional delivery status, and safe display data. Enforce unique `(user_id, notification_event_id)` at DB level. If email is enabled later, track each channel separately so an email retry cannot duplicate an in-app record.

### 4.4 Future notification preferences

Avoid building this table in MVP unless required by existing preferences conventions. Later: `notification_preferences` per user with category/channel flags and digest cadence. Defaults: in-app on; email off. Honor unsubscribe requirements for email.

## 5. Event taxonomy

| Event key                 | Trigger                                   | Recipients via targets          | MVP? |
| ------------------------- | ----------------------------------------- | ------------------------------- | ---- |
| `review.published`        | First public publication                  | Review, linked Wines/Producers  | Yes  |
| `review.updated`          | Meaningful edit to already-public Review  | Same                            | Yes  |
| `review.comment_created`  | Public comment/reply becomes visible      | Same                            | Yes  |
| `article.published`       | First public publication                  | Article, linked Wines/Producers | Yes  |
| `article.updated`         | Meaningful edit to already-public Article | Same                            | Yes  |
| `article.comment_created` | Public comment/reply becomes visible      | Same                            | Yes  |
| `wine.updated`            | Meaningful public Wine change             | Wine, Producer(s)               | Yes  |
| `wine.created`            | Public Wine added to Producer             | Producer(s)                     | Yes  |
| `vintage.created`         | New public Vintage                        | Parent Wine, Producer(s)        | Yes  |
| `vintage.updated`         | Meaningful public Vintage change          | Parent Wine, Producer(s)        | Yes  |
| `producer.updated`        | Meaningful public Producer change         | Producer                        | Yes  |

Optional later: comment edited/deleted, wine relationship changed, content archived/unpublished, moderation announcements. For deleted/hidden content, remove or redact stale notifications and recheck authorization.

**Publication rule:** Do not emit both `created` and `published` for the same first publication unless they represent distinct user-visible milestones. Define a canonical transition map for Draft → Published → Archived → Published. Re-publication after archive should be treated deliberately (prefer a distinct republished event or meaningful update), not an accidental duplicate.

**Meaningful fields:** Create explicit allowlists per entity after auditing actual columns and rich-text storage. For Review/Article, include title, body, publication, significant linked Wine/Producer changes; exclude timestamps, view counts, internal flags. For Wine/Producer/Vintage, include public display fields, not internal bookkeeping.

## 6. Backend services and job pipeline

Suggested structure (adapt to project conventions):

```text
app/models/follow.rb
app/models/notification_event.rb           # if needed
app/services/follows/create.rb              # optional
app/services/notifications/event_publisher.rb
app/services/notifications/affected_targets_resolver.rb
app/services/notifications/follower_resolver.rb
app/services/notifications/event_processor.rb
app/services/notifications/delivery_service.rb
app/jobs/notifications/process_event_job.rb
app/controllers/follows_controller.rb
```

**Flow:**

1. Business operation updates content in a database transaction.
2. Event publisher records the event and enough context to resolve associations reliably.
3. Transaction commits; event processing is enqueued. If enqueue fails, an outbox sweeper can retry undispatched events.
4. Affected-target resolver returns a normalized set of `(followable_type, followable_id)` targets.
5. Follower resolver performs indexed SQL query/UNION, filters follow timestamps, excludes actor, and deduplicates users.
6. Delivery service checks target visibility and user permissions; inserts notifications with `insert_all`/upsert or safe equivalent and unique constraint.
7. Mark event processed; retry transient errors. Log counts, duration, failures, and skipped unauthorized recipients.

**Scaling:** No N+1 lookups for every follower. Use set-based SQL and batch processing for popular Producers. Add instrumentation for event lag and delivery count. Set sensible job retry/backoff; handle deleted targets gracefully. Consider daily email digest only after in-app delivery is stable.

## 7. API contract

Use the project's actual route namespace and authentication conventions. Proposed endpoints:

| Method   | Endpoint                                                | Behavior                                                    |
| -------- | ------------------------------------------------------- | ----------------------------------------------------------- |
| `POST`   | `/follows`                                              | Create Follow, idempotent for duplicate request             |
| `DELETE` | `/follows/:id`                                          | Delete current user's Follow                                |
| `GET`    | `/follows`                                              | Paginated current-user follows, optionally filtered by type |
| `GET`    | `/follows/status?followable_type=Wine&followable_id=50` | Current user's follow state                                 |
| `GET`    | `/follows/statuses?...`                                 | Optional batch status for lists to avoid N+1 requests       |

Example POST:

```json
{ "followable_type": "Wine", "followable_id": 50 }
```

Example response:

```json
{
  "id": 123,
  "followable_type": "Wine",
  "followable_id": 50,
  "following": true,
  "created_at": "2026-10-23T00:00:00Z"
}
```

**Authorization:** Never accept `user_id` from client. Only the authenticated user can follow/unfollow or list their own follows. Return appropriate 401/403/404; avoid leaking inaccessible entity existence. Only allow known followable types. Restrict follow creation to entities visible to the user (published/authorized as applicable). Apply pagination and upper limits; use consistent error envelopes.

## 8. Frontend UX

Add a reusable `FollowButton` on Review, Article, Wine, Producer detail pages. States: `Follow`, `Following`, loading, sign-in required, error. Use accessible button labels, optimistic state only with rollback on error, and prevent double submission.

Add **Following** navigation to the user dashboard/profile (confirm current sidebar/navigation). Tabs/filters: All, Reviews, Articles, Wines, Producers. Each row links to its target and allows unfollow; support pagination, empty state, and deleted/unavailable content handling. Consider batch follow status for list cards later.

Notification UI should link to the event subject (e.g., comment on Review) and show a concise event title, actor where allowed, timestamp, unread/read state. Reuse existing notifications dropdown/page and unread badge.

## 9. Implementation phases, commands, and AI prompts

### Phase 0 — Repository audit and contract confirmation (mandatory)

**Deliverables:** actual model relationship diagram; existing notification flow inventory; approved event matrix; file-by-file implementation map; decisions on article/review Wine links and Vintage model.

**Manual commands:**

```bash
git clone https://github.com/romalopes/wine_words_api.git
git clone https://github.com/romalopes/wine_words_frontend.git
cd wine_words_api
rg -n 'class (Producer|Wine|Vintage|Review|Article|Comment|Notification|ProducerMembership)' app
rg -n 'has_many|belongs_to|has_one|polymorphic|notifications' app/models
rg -n 'notifications|follows|producer_memberships' config/routes.rb app db/schema.rb
cd ../wine_words_frontend
rg -n 'notification|producer|wine|review|article|Sidebar' src
```

**AI prompt 0:**

> Audit the current Wine Words API and frontend repositories. Do not modify code. Map User, ProducerMembership, Producer, Wine, Vintage, Review, Article, Comment, notifications, authorization, publication workflow, and relationships/join tables. Identify existing notification jobs/services and frontend UI. Confirm Rails version, migration style, test framework, API route conventions, and deployment queue backend. Compare the proposed Follow event propagation requirements with actual associations, identify gaps, and output a file-by-file implementation plan with specific code references. Never assume an association without locating it.

**Gate:** Explicitly resolve whether Articles/Reviews can link to multiple Wines/Producers/Vintages and how published visibility is enforced.

### Phase 1 — Follow schema and model

**Tasks:** Migration, associations, allowed types, uniqueness, orphan cleanup, unit tests. Keep membership untouched.

**Commands:**

```bash
cd wine_words_api
bin/rails generate migration CreateFollows
# Edit generated migration per the approved schema.
bin/rails db:migrate
bin/rails db:migrate:status
```

**AI prompt 1:**

> Implement the polymorphic Follow model for User → Review/Article/Wine/Producer using existing Rails conventions. Add database uniqueness and efficient reverse lookup indexes, associations and validation. Do not add follower to ProducerMembership membership_type and do not change producer membership behavior. Add tests for allowed types, duplicate/concurrent follow prevention, cleanup on deletion, and disallowed targets. Show changed files and migration rollback strategy.

**Gate:** Model tests pass and existing producer membership tests remain unchanged.

### Phase 2 — Follow API and authorization

**Tasks:** Routes/controllers/serializer, current-user scope, pagination, status endpoint, access control, API request tests.

**AI prompt 2:**

> Implement authenticated REST endpoints to follow/unfollow and list followed Reviews, Articles, Wines, and Producers. Derive user from current authentication context, never request payload. Enforce target visibility, idempotent duplicate POST, ownership for DELETE, pagination/filtering, and consistent errors. Add request tests for unauthenticated, unauthorized, missing, unsupported, duplicate, and successful operations. Reuse project conventions and avoid exposing private entities.

**Gate:** Full request tests pass; no cross-user data leakage.

### Phase 3 — Event publishing and reliability

**Tasks:** Event catalog, meaningful-change detection, publication transition logic, transactional event persistence, job enqueue/retry, event tests.

**AI prompt 3:**

> Design and implement notification domain event publishing for meaningful public changes: Review/Article published/updated/commented, Wine updated/created, Vintage created/updated, Producer updated. Inspect existing callbacks and notification infrastructure first. Prefer service-level publication after successful business transactions, avoid duplicate callback events, and persist events reliably using existing infrastructure or an outbox. Never publish draft/autosave/analytics/import noise. Add tests for publication transitions, retry, and idempotency.

**Gate:** Each meaningful business operation emits exactly one canonical event; drafts and imports do not flood events.

### Phase 4 — Propagation and recipient resolution

**Tasks:** Affected-target resolution, inherited follows, SQL distinct recipients, timing, permission checks, dedupe, scalable delivery, integration tests.

**AI prompt 4:**

> Implement Notifications::AffectedTargetsResolver and FollowerResolver against the actual Wine Words associations. A Review/Article event must notify direct followers, followers of every linked Wine (including Wine inferred through Vintage), direct linked Producers, and Producers of linked Wines. Wine/Vintage events propagate to relevant Producer followers. Producer events target Producer followers. Use indexed set-based SQL, deduplicate across all follow paths, exclude the actor, enforce Follow creation time and current follow state, respect publication/authorization, and create at most one notification per user per event. Add exhaustive unit/integration tests, including multiple Wines, overlapping follows, deleted links, and jobs retried twice.

**Gate:** Recipient matrix below passes; no duplicate notifications.

### Phase 5 — React Follow UI and Following page

**Tasks:** API client/types, reusable button, four detail pages, dashboard filters, accessibility, tests.

**AI prompt 5:**

> Implement the Wine Words React Follow UI using existing frontend architecture. Add reusable FollowButton to Review, Article, Wine, Producer detail pages. Integrate authenticated follow status, create/delete operations, loading/error states, and rollback after failed optimistic changes. Add a paginated Following page in existing user dashboard/navigation with All/Reviews/Articles/Wines/Producers filters, unfollow actions, and links. Reuse existing components and styling. Add component and API mock tests.

**Gate:** User can follow/unfollow all four types and see consistent state after refresh.

### Phase 6 — Notification UI integration and end-to-end testing

**Tasks:** Reuse notification list/badge/read endpoints, link to source, test visibility, test asynchronous behavior and retries.

**AI prompt 6:**

> Integrate Follow-generated notifications with Wine Words' existing notifications UI and backend. Render safe, useful event messages and links; support read/unread and existing unread counts. Add end-to-end tests for direct Review follow, Wine inherited notifications, Producer inherited notifications, comment replies, deduplication, actor exclusion, unauthorized/private content, and unfollow-before-processing. Verify background jobs and frontend refresh behavior. Do not build a parallel notification system.

**Gate:** E2E scenarios pass with real API and background worker configuration.

### Phase 7 — Performance, rollout, and operations

**Tasks:** Explain plans and indexes, batching, event observability, feature flag, deployment order, load tests, rollout and rollback docs.

**AI prompt 7:**

> Audit Follow notification performance and production readiness. Review SQL EXPLAIN for large Producers, avoid N+1 queries, batch recipients, verify indexes, queue retry/backoff, outbox recovery, and idempotent delivery. Add structured logs/metrics for event age, recipient count, delivery failures, and processing duration, integrating existing Sentry/OpenTelemetry where configured. Document feature flag, database migration rollout, queue deployment, monitoring, and rollback without losing pre-existing notifications.

**Gate:** Load tests with many Wine/Producer follows show bounded memory and acceptable job latency; no user-facing request waits for fanout.

### Phase 8 — Optional notification preferences and email digests (deferred)

**Tasks:** Preferences UI/schema, in-app category toggles, daily/weekly digest jobs, Brevo delivery, unsubscribe handling.

**AI prompt 8:**

> Extend the working Follow notification engine with per-user notification category preferences and optional daily/weekly email digests. Default to in-app enabled and email disabled. Reuse Wine Words' existing Brevo HTTP email delivery implementation and unsubscribe conventions. Aggregate events by user and entity, prevent duplicate digest sends, honor email opt-outs, and add tests for scheduling, retries, privacy, and digest composition. Keep immediate email-per-comment disabled by default.

**Gate:** Digest and preference tests pass; no duplicate email delivery.

## 10. Recipient acceptance test matrix

| Scenario                                                           | Expected                                                  |
| ------------------------------------------------------------------ | --------------------------------------------------------- |
| A follows Review R; another user comments on R                     | A gets one notification                                   |
| A follows Article A1; A1 is meaningfully updated while published   | A gets one notification                                   |
| A follows Wine W; Review R linked to W is published                | A gets one notification                                   |
| A follows Wine W; Article linked via Vintage V of W gets a comment | A gets one notification if association exists             |
| A follows Producer P; new Wine W is added to P                     | A gets one notification                                   |
| A follows Producer P; new Vintage V is added to P's Wine W         | A gets one notification                                   |
| A follows Producer P; Review on W gets a reply                     | A gets one notification                                   |
| A follows Producer P; Article directly linked to P gets updated    | A gets one notification                                   |
| A follows R + W + P; R linked to W/P gets a comment                | A gets exactly one notification                           |
| A writes a comment on followed R                                   | A gets no self-notification                               |
| Draft Article linked to W is edited                                | No ordinary follower notification                         |
| Content is private or recipient cannot access it                   | No exposed content or unauthorized notification           |
| A follows after event occurred                                     | No historical notification                                |
| A unfollows before event is processed                              | No new notification from that event                       |
| Job is retried or run twice                                        | At most one notification per user/event                   |
| Content linked to multiple Wines and Producers                     | All eligible followers notified once                      |
| Wine/Review deleted before delivery                                | Graceful skip or safe redaction; no broken exception loop |

## 11. Test strategy

- **Models:** validation, uniqueness, polymorphic target allowlist, destroy cleanup.
- **API:** authentication, authorization, idempotency, filtering, pagination, invalid inputs, concurrency.
- **Events:** meaningful field allowlists, publication state transitions, after-commit reliability, import suppression.
- **Resolvers:** all direct and inherited paths, multiple associations, overlapping follows, timestamps, current unfollow state.
- **Delivery:** uniqueness under concurrency, retry, actor exclusion, permission filtering, deleted subjects.
- **Frontend:** button states, auth redirects, error rollback, Following filters, unread navigation.
- **E2E:** full flow through Rails API, queue worker, notification persistence, React UI.
- **Performance:** representative high-follower Producer, explain plans, batch size, queue lag.

Run project-specific commands after Phase 0 confirms setup, typically:

```bash
# API
bundle exec rails test           # or bundle exec rspec
bundle exec rubocop             # if configured

# Frontend
npm ci
npm run lint
npm run test                    # if configured
npm run build
```

Do not introduce test tooling merely because the example command mentions it; use the actual repository stack.

## 12. Risks and mitigations

| Risk                                                    | Mitigation                                                                                   |
| ------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| Review/Article associations differ from assumptions     | Mandatory Phase 0 audit; resolver works from real joins                                      |
| Notification storm from edits/imports                   | Meaningful field allowlists, publish transitions, import suppression, future digest grouping |
| Duplicate notifications through inherited follows       | `DISTINCT` recipient selection plus DB unique `(user_id, event_id)`                          |
| Missed events after commit/queue failure                | Persisted event/outbox + recovery job                                                        |
| Relationship changed before async processing            | Store normalized affected target snapshot or define deterministic resolution time            |
| Follower added after event or removed before processing | Timestamp boundary and current Follow recheck                                                |
| Private/unpublished data leak                           | Visibility checks at event and delivery/read time                                            |
| Large Producer fanout                                   | Indexed queries, batches, async jobs, observability                                          |
| ProducerMembership conflated with Follow                | Separate tables, models, API and tests                                                       |
| Existing notifications duplicated by new design         | Audit and reuse current notification infrastructure                                          |

## 13. Deployment and rollback

1. Deploy additive schema and indexes first; keep feature disabled.
2. Deploy backend API, event publisher, worker, and idempotent delivery with feature flag off.
3. Enable events for internal test accounts; verify queue and notification behavior.
4. Deploy frontend Follow controls and Following page; gradually enable for users.
5. Monitor duplicate constraints, queue failures, notification counts, lag, and visibility errors.
6. Rollback by disabling Follow event publication and UI while preserving existing Follow and notification data. Only reverse migrations after confirming no production data depends on them.

## 14. Final definition of done

- [ ] Follow is independent of ProducerMembership and does not use `membership_type = follower`.
- [ ] All four followable types work with authenticated API and React UI.
- [ ] Following page supports filters and unfollow.
- [ ] Direct Review/Article and inherited Wine/Producer notifications work.
- [ ] New Wine and Vintage activity propagates to appropriate followers.
- [ ] Comments and replies propagate correctly.
- [ ] Meaningful public updates notify; drafts/internal updates do not.
- [ ] Deduplication and retry safety are database-enforced.
- [ ] Privacy, actor exclusion, timing, and unfollow rules are tested.
- [ ] Existing notification UI is reused, not duplicated.
- [ ] Performance and production rollout are documented and verified.
- [ ] Optional email preferences/digests remain a separate deliverable unless explicitly approved.

## 15. Recommended implementation order

**MVP:** Phases 0–7, with in-app notifications only.
**Later:** Phase 8, optional email digest and preferences.
**Future extensions:** follow other polymorphic resources, follower counts, grouped activity feeds, realtime push, user-follow suggestions.
