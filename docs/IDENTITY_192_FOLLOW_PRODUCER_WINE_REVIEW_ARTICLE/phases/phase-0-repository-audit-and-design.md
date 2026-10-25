# Phase 0 — Repository Audit and Approved Design

**Status:** Completed  
**Date:** 2026-10-25  
**Repositories:** API (wine_words_api) · Frontend (wine_words)

---

## 1. Verified Repository State

### API Repository
- **Branch:** `main` (commit `d3d79f0` - "191 - LINK USER PRODUCER")
- **Rails version:** 7.2.x (Ruby 3.4.2)
- **Queue adapter:** Solid Queue configured but **overridden by `:async` in production.rb** — must be fixed
- **Test framework:** RSpec with transactional fixtures
- **Authentication:** Devise + custom `current_user` in `ApplicationController`
- **Authorization:** Role-based (`wine_manager?`, `admin?`) + ProducerMembership

### Frontend Repository
- **Branch:** `main` (matches `origin/main`)
- **Framework:** React 18 + TypeScript + Vite
- **Routing:** React Router v6
- **State:** React Context (AuthContext) + TanStack Query
- **Testing:** Vitest + React Testing Library
- **Styling:** CSS Modules + global `index.css`

---

## 2. Confirmed Domain Relationships

```text
User
├── ProducerMembership ──> Producer
│   membership_type: owner | manager | contributor  (no "follower" type)
│
└── Follow ──────────────> Producer | Wine | Review | Article

Producer
└── Wines
    └── Vintages
        └── Reviews

Article
├── ArticleVintages ──> Vintages ──> Wines ──> Producers
├── ArticleProducers ─> Producers
└── ArticleReviews ───> Reviews

Review
└── belongs_to Vintage (exactly one)
    └── belongs_to Wine
        └── belongs_to Producer

Comment
└── polymorphic commentable: Wine | Review | Article
```

### Critical Corrections to Original Assumptions

| Original Assumption | Actual Model |
|---------------------|--------------|
| Review links to multiple Wines/Vintages/Producers | **Review belongs to exactly one Vintage** |
| Article links only through Vintages | **Article also has direct Producers via `article_producers`** |
| Wine comments trigger follow notifications | **Issue #192 only requests Review/Article comment propagation** |
| ProducerMembership could include "follower" | **Must remain owner/manager/contributor only** |

---

## 3. Existing Notification Infrastructure

### Current `Notification` Model
- Tied to `WinePackage` reminders via `wine_package_id`, `notification_type`, `scheduled_date`
- Uniqueness: `(wine_package_id, notification_type, scheduled_date, recipient_id)`
- Lifecycle: `sent_at` (email sent) → `read_at` (user read)
- Controller only returns notifications where `sent_at` is present
---

## 4. Publication & Visibility Rules

### Review
- `status` enum: `draft` | `published`
- `Review.visible_to(user)` scope: published reviews + user's own drafts + wine_manager sees all
- Draft reviews are 404 for unauthorized users (comments controller enforces this)

### Article
- `status` enum: `draft` | `published`
- `published_at` timestamp set on publish
- Similar visibility: published articles + user's own drafts + wine_manager sees all

### Wine / Producer
- No publication status — always public when created
- Producer updates restricted to membership roles

---

## 5. Approved Event Matrix

### Review Events
| Event | Trigger | Affected Targets (for follower resolution) |
|-------|---------|--------------------------------------------|
| `review.published` | First `draft` → `published` transition | Review, Review's Vintage's Wine, Wine's Producer |
| `review.updated` | Meaningful edit while `published` | Same as above |
| `review.comment_created` | Visible comment/reply on published Review | Same as above |

**Meaningful Review fields:** `title`, `comment`, `score`, `drink_from`, `drink_to`, `drink_plus`, `vintage_id`, public category relationships  
**Excluded:** `updated_at`, search vectors, deadline-only changes, analytics, draft edits, article-link bookkeeping

### Article Events
| Event | Trigger | Affected Targets |
|-------|---------|------------------|
| `article.published` | First `draft` → `published` transition | Article, linked Wines (via Vintages), direct Producers, inherited Producers (via Vintages' Wines) |
| `article.updated` | Meaningful edit while `published` | Same captured relationships |
| `article.comment_created` | Visible comment/reply on published Article | Same as above |

**Meaningful Article fields:** `title`, `abstract`, `body`, categories, tags, linked Vintages, direct Producers, published Review links  
**Excluded:** deadline-only changes, search vectors, draft edits, analytics, timestamps

### Wine/Vintage/Producer Events
| Event | Trigger | Affected Targets |
|-------|---------|------------------|
| `wine.created` | New Wine committed | Producer |
| `wine.updated` | Meaningful public Wine edit | Wine, Producer |
| `vintage.created` | New Vintage committed | Wine, Producer |
| `vintage.updated` | Meaningful Vintage edit | Wine, Producer |
| `producer.updated` | Meaningful Producer edit | Producer |

**Meaningful fields:** explicit allowlists per model — no internal counters, timestamps, search indexing, cache changes

### Comment Behavior
- Only comments/replies on **published** Reviews and Articles generate follow events
- Draft content comments do not generate ordinary follower notifications
- Soft deletion: no MVP notification
- Comment body: **not** copied into event metadata
- Reply: single `*.comment_created` event with `reply: true` metadata
- Actor exclusion: event creator never receives notification

---

## 6. Data Model Changes (Approved)

### 6.1 `follows` Table (New)
```sql
CREATE TABLE follows (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followable_type VARCHAR NOT NULL,
  followable_id BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT follows_unique UNIQUE (user_id, followable_type, followable_id),
  CONSTRAINT follows_type_check CHECK (followable_type IN ('Producer','Wine','Review','Article'))
);
CREATE INDEX idx_follows_reverse ON follows (followable_type, followable_id, user_id);
```

### 6.2 `notification_events` Table (New — Outbox Pattern)
```sql
CREATE TABLE notification_events (
  id BIGSERIAL PRIMARY KEY,
  event_type VARCHAR NOT NULL,
  subject_type VARCHAR NOT NULL,
  subject_id BIGINT NOT NULL,
  actor_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  affected_targets JSONB NOT NULL,  -- snapshot of (type, id) pairs at event time
  metadata JSONB NOT NULL DEFAULT '{}',  -- safe display data only
  idempotency_key VARCHAR NOT NULL,
  processing_started_at TIMESTAMPTZ,
  processed_at TIMESTAMPTZ,
  failed_at TIMESTAMPTZ,
  attempts INT NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX idx_notification_events_idempotency ON notification_events (idempotency_key);
CREATE INDEX idx_notification_events_pending ON notification_events (processed_at, failed_at) WHERE processed_at IS NULL AND failed_at IS NULL;
CREATE INDEX idx_notification_events_subject ON notification_events (subject_type, subject_id);
```

### 6.3 `notifications` Table (Extended — Per-Recipient Deliveries)
```sql
-- Existing columns preserved
-- New columns:
ALTER TABLE notifications ADD COLUMN notification_event_id BIGINT REFERENCES notification_events(id) ON DELETE SET NULL;
ALTER TABLE notifications ADD COLUMN actor_id BIGINT REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE notifications ADD COLUMN delivered_at TIMESTAMPTZ;
ALTER TABLE notifications ADD COLUMN target_path VARCHAR;
ALTER TABLE notifications ADD COLUMN target_label VARCHAR;

-- New partial unique index for follow-based notifications
CREATE UNIQUE INDEX idx_notifications_user_event ON notifications (recipient_id, notification_event_id) WHERE notification_event_id IS NOT NULL;

-- Backfill existing WinePackage rows:
UPDATE notifications SET delivered_at = sent_at WHERE notification_event_id IS NULL AND sent_at IS NOT NULL;
```

### 6.4 Production Queue Fix
```ruby
# config/environments/production.rb
---

## 7. API Contract (Final)

### Follows
| Method | Endpoint | Behavior |
|--------|----------|----------|
| `POST` | `/api/v1/follows` | Create follow (idempotent) |
| `DELETE` | `/api/v1/follows/:id` | Delete current user's follow |
| `GET` | `/api/v1/follows` | Paginated current-user follows, `?type=Wine` filter |
| `GET` | `/api/v1/follows/status?followable_type=Wine&followable_id=50` | Current user's follow state |
| `GET` | `/api/v1/follows/statuses?followable_type=Wine&ids[]=1&ids[]=2` | Batch status for lists |

### Notifications (Extended)
| Method | Endpoint | Behavior |
|--------|----------|----------|
| `GET` | `/api/v1/notifications` | All deliveries (package + follow), paginated, `?unread=true` |
| `GET` | `/api/v1/notifications/unread_count` | Combined unread count |
| `PATCH` | `/api/v1/notifications/:id/mark_read` | Mark delivered notification read |
| `PATCH` | `/api/v1/notifications/mark_all_read` | Mark all delivered unread as read |

**Serializer additions:** `notification_event_id`, `event_type`, `actor_name`, `target_path`, `target_label`, `delivered_at`  
**Backward compatibility:** Existing `wine_package_id`, `package_status`, `notification_type` fields preserved

---

## 8. File-by-File Implementation Map

### Phase 1 — Follow Schema & Model
| File | Action |
|------|--------|
| `db/migrate/xxxxxx_create_follows.rb` | Create migration |
| `app/models/follow.rb` | New model |
| `app/models/user.rb` | Add `has_many :follows` |
| `app/models/producer.rb` | Add `has_many :follows, as: :followable` |
| `app/models/wine.rb` | Add `has_many :follows, as: :followable` |
| `app/models/review.rb` | Add `has_many :follows, as: :followable` |
| `app/models/article.rb` | Add `has_many :follows, as: :followable` |
| `spec/models/follow_spec.rb` | Model tests |

### Phase 2 — Follow API
| File | Action |
|------|--------|
| `config/routes.rb` | Add follows routes |
| `app/controllers/api/v1/follows_controller.rb` | New controller |
| `app/serializers/follow_serializer.rb` | New serializer |
| `spec/requests/api/v1/follows_spec.rb` | Request specs |

### Phase 3 — Event Schema & Publishing
| File | Action |
|------|--------|
| `db/migrate/xxxxxx_create_notification_events.rb` | Migration |
| `db/migrate/xxxxxx_extend_notifications.rb` | Extend notifications |
| `app/models/notification_event.rb` | New model |
| `app/models/notification.rb` | Extend associations |
| `app/services/notifications/event_publisher.rb` | Publisher service |
| `app/services/notifications/meaningful_change_detector.rb` | Change detection |
| `app/jobs/notifications/process_event_job.rb` | Processing job |
| `app/jobs/notifications/recovery_job.rb` | Recovery job |
| `config/recurring.yml` | Add recovery job |
| `config/environments/production.rb` | Fix queue adapter |
| `spec/models/notification_event_spec.rb` | Model tests |
| `spec/services/notifications/event_publisher_spec.rb` | Service tests |
| `spec/jobs/notifications/process_event_job_spec.rb` | Job tests |

### Phase 4 — Recipient Resolution & Delivery
| File | Action |
|------|--------|
| `app/services/notifications/affected_targets_resolver.rb` | Target resolver |
| `app/services/notifications/follower_resolver.rb` | Follower resolver |
| `app/services/notifications/visibility.rb` | Visibility checks |
| `app/services/notifications/delivery_service.rb` | Delivery service |
| `spec/services/notifications/affected_targets_resolver_spec.rb` | Resolver tests |
| `spec/services/notifications/follower_resolver_spec.rb` | Resolver tests |
| `spec/services/notifications/delivery_service_spec.rb` | Delivery tests |

### Phase 5 — React Follow UI
| File | Action |
|------|--------|
| `src/types/follow.ts` | TypeScript types |
| `src/services/followsApi.ts` | API client |
| `src/components/FollowButton.tsx` | Reusable button |
| `src/components/FollowButton.test.tsx` | Component tests |
| `src/components/Following.tsx` | Following page |
| `src/components/Following.test.tsx` | Page tests |
| `src/components/ReviewDetail.tsx` | Integrate FollowButton |
| `src/components/ArticleDetail.tsx` | Integrate FollowButton |
| `src/components/WineDetail.tsx` | Integrate FollowButton |
| `src/components/ProducerDetail.tsx` | Integrate FollowButton |
| `src/components/AppRoutes.tsx` | Add `/following` route |
| `src/components/Header.tsx` | Add Following nav link |

### Phase 6 — Notification UI
| File | Action |
|------|--------|
| `src/types/notification.ts` | Extended types |
| `src/services/api.ts` | Extended notifications API |
| `src/components/Notifications.tsx` | Generalized feed |
| `src/components/Notifications.test.tsx` | Updated tests |
| `src/components/NotificationBell.tsx` | Updated bell |
---

## 9. Test Strategy Summary

### API
- Follow model: allowed types, uniqueness, concurrency, cleanup
- Follow API: auth, idempotency, visibility, pagination, batch status
- NotificationEvent: idempotency, state transitions, recovery
- Notification: delivery uniqueness, delivered_at vs sent_at, backfill
- Services: resolver correctness, deduplication, actor exclusion, visibility recheck
- Jobs: retry safety, deleted subject handling, batch processing
- ProducerMembership regression: membership_type still only owner/manager/contributor

### Frontend
- FollowButton: all states, optimistic update + rollback, accessibility
- Following page: filters, pagination, unfollow, empty/error/loading
- Detail page integration: all four types
- Notifications: mixed package + follow feed, mark read, unread count
- NotificationBell: real-time count updates via event bus

---

## 10. Rollback Strategy

1. **Disable feature flag** — stops event publishing and UI
2. **Preserve data** — Follow, NotificationEvent, Notification rows remain
3. **Reverse migrations only after** confirming no production data depends on them
4. **Queue adapter fix** is independent and stays

---

## 11. Differences from Original Proposal

| Area | Original Proposal | Approved Design |
|------|-------------------|-----------------|
| Notification model | Replace with generic | **Extend** existing, add `delivered_at`, `notification_event_id` |
| Event storage | Inline in job | **Persisted outbox table** (`notification_events`) |
| Idempotency | Application-level | **DB unique index** on `idempotency_key` + `(user_id, event_id)` |
| Queue | Assume solid_queue | **Fix production override** to actually use solid_queue |
| Review propagation | Assumed multi-wine | **Single Vintage → Wine → Producer** |
| Article propagation | Vintages only | **Vintages + direct Producers** |
| Wine comments | Included | **Excluded per issue #192** |
| Phase 8 | Deferred | **Included per user request** |

---

## 12. Gate: Phase 0 Complete

✅ Repository audited  
✅ Relationships confirmed  
✅ Event matrix approved  
✅ Data model approved  
✅ API contract finalized  
✅ Implementation map created  
✅ Differences documented  

**Ready for Phase 1.**
| `src/components/NotificationBell.test.tsx` | Updated tests |
| `app/serializers/notification_serializer.rb` | Extended serializer |
| `app/controllers/api/v1/notifications_controller.rb` | Extended controller |

### Phase 7 — Performance & Rollout
| File | Action |
|------|--------|
| `config/initializers/feature_flags.rb` | Follow feature flag |
| `docs/.../phase-7-performance-rollout-and-operations.md` | Operations doc |

### Phase 8 — Preferences & Digests
| File | Action |
|------|--------|
| `db/migrate/xxxxxx_add_notification_preferences.rb` | Preferences migration |
| `app/models/notification_preference.rb` | Preferences model |
| `app/mailers/follow_digest_mailer.rb` | Digest mailer |
| `app/jobs/notifications/digest_job.rb` | Digest job |
| `config/recurring.yml` | Add digest job |
| `src/components/NotificationPreferences.tsx` | Preferences UI |
| `spec/...` | Full test coverage |
# REMOVE this line (overwrites solid_queue):
# config.active_job.queue_adapter = :async

# Keep only:
config.active_job.queue_adapter = :solid_queue
```
- Types: `wine_package_deadline`, `wine_package_arrived`, `wine_package_completed`, `wine_package_rejected`

### Current Notification Jobs
- `WinePackages::SendReviewDeadlineNotificationsJob` (recurring, daily)
- `WinePackages::Notifications::Schedule` service creates reminders idempotently
- Delivered via `WinePackagesMailer` + in-app list

### Current API
```
GET    /api/v1/notifications
GET    /api/v1/notifications/unread_count
PATCH  /api/v1/notifications/:id/mark_read
PATCH  /api/v1/notifications/mark_all_read
```