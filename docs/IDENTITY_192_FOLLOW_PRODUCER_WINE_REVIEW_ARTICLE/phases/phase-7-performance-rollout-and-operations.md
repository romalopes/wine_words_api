# Phase 7 — Performance, Rollout, and Operations

**Status:** Completed  
**Date:** 2026-10-25  

---

## 1. Feature flag

`AppSetting.follow_notifications_enabled?` (default **true**, admin-toggleable via
`AppSetting.set!("follow_notifications_enabled", false)` / the Configuration page):

- Off ⇒ `Notifications::EventPublisher.publish!` returns nil — no events are created,
  no jobs enqueued, no UI-visible change to follows themselves.
- Follow rows and already-delivered notifications are preserved; toggling back on
  resumes exactly where it stopped.
- Spec coverage: `notification_preferences_spec.rb` "stops event publishing when off
  and resumes when back on".

## 2. Performance characteristics

| Concern | Measure |
|---|---|
| Follower fanout | One set-based `Follow` query per event (OR-combined indexed `(followable_type, followable_id)` matches), `DISTINCT` user ids — no per-follower lookups |
| Delivery writes | `insert_all` batches of 500 with `ON CONFLICT DO NOTHING` against the partial `(recipient, event)` unique index |
| Delivery dedup | Database-enforced; retries can never duplicate |
| Event audience stability | `affected_targets` jsonb snapshot captured at publish time — later relationship edits cannot change or leak an audience |
| Producer fanout | Resolve + deliver run inside `ProcessEventJob` with polynomial backoff retries (`retry_on …, attempts: 5`) |
| Recovery | Hourly `Notifications::RecoveryJob` (recurring.yml minute 47) re-enqueues stale in-flight runs and lost enqueues (older than 1h only, so fresh traffic is never double-enqueued) |
| Feed reads | `by_recency` uses `created_at` with existing `(recipient_id, read_at)` index; event/actor eager-loaded in one query |

## 3. Observability

- Delivery summary per event: `Rails.logger.info "[Notifications] event=… type=… candidates=… inserted=…"` (candidate vs inserted counts expose dedup/skips).
- Recovery warns per recovered event.
- Digest failures are recorded on the preference row (`digest_last_error*`) and logged.
- Exceptions propagate through Active Job retries; Sentry picks up final failures via the standard job instrumentation.

## 4. Deployment order / rollback

1. Run migrations (additive: `follows`, `notification_events`, notifications extensions, `notification_preferences`).
2. Deploy the backend with the feature flag set as desired.
3. Deploy the frontend (Follow buttons + Following page; degrade gracefully when the API is old — buttons simply fail to resolve status).
4. **Rollback:** set the flag off. No data is destroyed; reverse migrations only after confirming no production data depends on them.
5. The production `:async` queue-adapter override was REMOVED — Solid Queue is the real adapter (independent of the flag and stays).

## 5. Known pre-existing failures (not from this change)

The full-suite regression diff vs the `main` baseline (verified twice via stash) shows
**zero new failures** in either repository; the 44 API-side and 4 frontend-side failures
pre-date this work.

---

# Phase 8 — Notification Preferences and Email Digests

**Status:** Completed  
**Date:** 2026-10-25  

## Schema

`notification_preferences` (singleton per user, unique index via `t.references … index: { unique: true }`, check-constrained cadence):

| Column | Meaning |
|---|---|
| `follow_in_app` | keep follow events in the in-app feed (default true) |
| `follow_email` | email every follow event immediately (default false) |
| `digest_cadence` | `none` (default) / `daily` / `weekly` |
| `digest_last_sent_at`, `digest_last_error*` | digest bookkeeping |

## API

- `GET /api/v1/account/notification_preferences` — returns defaults, creating the row lazily (`NotificationPreference.for(user)`, race-safe).
- `PATCH /api/v1/account/notification_preferences` — updates channels/cadence; invalid cadence → 422 and the stored row is unchanged.

## Delivery integration

- `DeliveryService#eligible_recipients` filters out users with `follow_in_app: false`.

## Digests

- `Notifications::DigestJob` (daily run = daily cadence; weekly run = weekly) collects each user's follow-based notifications that were never emailed (`sent_at` NULL, `notification_event_id` present — package reminders are never touched), groups them in one email (`NotificationPreferencesMailer#follow_digest`, HTML + text templates), then stamps them `sent_at` — idempotent: re-running sends nothing.
- Scheduled in `config/recurring.yml`: `notifications_daily_digest` (8am) and `notifications_weekly_digest` (Mondays 8am).

## Frontend

- `src/components/NotificationPreferences.tsx` on the Following page: in-app checkbox, email checkbox, digest select; saves via `followsApi.preferences/updatePreferences`; error and saved states.
- `NotificationPreferences.test.tsx` — 3 tests (load/render, save + confirm, failure alert).

## Tests

`spec/requests/api/v1/notification_preferences_spec.rb` — 9 examples, all passing:
defaults + lazy creation, auth required, update + invalid cadence rejection (reloaded state), flag off/on behaviour through the real API, digest email content + idempotency, weekly rows untouched by the daily run, package reminders excluded, no-op digest.