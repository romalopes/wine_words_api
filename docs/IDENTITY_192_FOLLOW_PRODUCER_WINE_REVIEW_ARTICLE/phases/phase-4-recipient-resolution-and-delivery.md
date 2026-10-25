# Phase 4 — Recipient Resolution and Delivery

**Status:** Completed  
**Date:** 2026-10-25  

---

## 1. Migrations

- `20261024141743_create_notification_events.rb` — outbox table with `event_type`, `subject_type/subject_id`, nullable `actor_id` (FK → users, nullify), `occurred_at`, `affected_targets` (jsonb snapshot), `metadata` (jsonb, safe display data only), unique `idempotency_key`, processing state (`processing_started_at`, `processed_at`, `failed_at`, `attempts`, `last_error`), partial pending index, subject index.
- `20261024141744_extend_notifications_for_follows.rb` — adds `notification_event_id` (FK, nullify), `actor_id`, `delivered_at`, `target_path`, `target_label`; partial unique index `(recipient_id, notification_event_id) WHERE notification_event_id IS NOT NULL`; backfill `delivered_at = sent_at` for legacy package rows.

## 2. Models

- `NotificationEvent` — 11 event types (`review.published`, `review.updated`, `review.comment_created`, `article.published`, `article.updated`, `article.comment_created`, `wine.created`, `wine.updated`, `vintage.created`, `vintage.updated`, `producer.updated`); scopes `pending` / `processed` / `failed` / `stale_pending(cutoff)`; state mutators.
- `Notification` — extended with `notification_event`, `actor` associations, new TYPES, `delivered_at` lifecycle (`delivered?`, `mark_delivered!`), and reworked scopes:
  - `delivered` = in-app visible (delivered_at OR sent_at present) — package reminders unchanged in behavior
  - `undelivered` = `sent_at IS NULL` (email queue; the deadline job also filters by its own type, so follow rows are never emailed)

## 3. Publishing

- `Notifications::EventPublisher.publish!` — deterministic idempotency keys for `published` / `comment_created` / `created` events; random keys per meaningful `updated` event. Snaps affected targets via the resolver and stores safe metadata (labels/slugs only, never comment/article bodies). Rescues both `RecordNotUnique` and uniqueness `RecordInvalid` as idempotent repeats. Enqueues `ProcessEventJob` after creation.
- `Notifications::MeaningfulChangeDetector` — explicit field allowlists per model (Review: title/comment/score/drink window/vintage; Article: title/abstract/body; Wine: name/color/closure/alcohol/volume/description/producer; Vintage: year; Producer: name/description/type/founded year). Everything else (timestamps, deadlines, search vectors, draft edits) is never an event.

## 4. Wiring (controllers)

| Controller | Event |
|---|---|
| `ReviewsController#create/update` | `review.published` on first publish (draft→published, incl. create-published); `review.updated` on meaningful edit while published. Deadline-only and draft edits never publish. |
| `ArticlesController#create/update` | `article.published` / `article.updated` — same rules |
| `WinesController#create/update` | `wine.created` / `wine.updated` (meaningful only) |
| `VintagesController#create` | `vintage.created` |
| `ProducersController#update` | `producer.updated` (meaningful only) |
| `CommentableActions#create` | `review.comment_created` / `article.comment_created` (published subjects only; wine comments excluded; deterministic per-comment key; reply flag in metadata) |

## 5. Reliability

- **Queue fix:** removed the `config.active_job.queue_adapter = :async` override in `config/environments/production.rb` — Solid Queue is now the real production adapter (the later `:async` line silently overrode it before).
- **Recovery:** `Notifications::RecoveryJob` re-enqueues events whose worker died mid-run (`processing_started_at` older than 1h) or whose enqueue was lost (NULL start AND older than 1h — fresh never-started events are left alone). Scheduled hourly in `config/recurring.yml` (`notifications_recovery`, minute 47).

## 6. Tests

- `spec/models/notification_event_spec.rb` — 12 examples (validations, state transitions, targets normalization, scopes, event-deletion nullify).
- `spec/services/notifications/pipeline_spec.rb` — 21 examples (resolver propagation for all subject kinds, publisher idempotency + enqueue, follower eligibility incl. late follows, delivery dedup/visibility, visibility rules).
- `spec/jobs/notifications/process_event_job_spec.rb` — 13 examples (processed marking, unread deliveries, missing event skip, idempotent reprocessing, failure recording + retry re-enqueue, deleted-subject skip, recovery re-enqueue).

---

# Phase 4 — Recipient Resolution and Delivery

**Status:** Completed  
**Date:** 2026-10-25  

## Services (app/services/notifications/)

- `AffectedTargetsResolver` — Review → [Review, Wine, Producer] via `vintage.wine.producer`; Article → [Article, linked Wines via Vintages, direct Producers + inherited Producers]; Wine/Vintage → [Wine, Producer]; Producer → [Producer]. Snapshot stored on the event at publish time.
- `FollowerResolver` — OR-combined indexed scope over the event's targets; `created_at <= occurred_at` boundary; actor excluded; `DISTINCT` user ids (dedup of inherited coverage in SQL).
- `Visibility` — delivery-time recheck; unpublished/archived subjects produce zero deliveries (event still marked processed).
- `DeliveryService` — set-based `insert_all` with `ON CONFLICT DO NOTHING` against the `(recipient, event)` partial unique index → reprocessing can never duplicate. Rows are created already `delivered` (in-app), `sent_at` NULL (email is a later phase), with `target_path`/`target_label` for the frontend link and a composed message.

## Gate: Phases 3–4 Complete

- [x] Outbox table + per-event dedup enforced by the database
- [x] Publishing wired into all content controllers
- [x] Recovery job + hourly recurring schedule
- [x] Production Solid Queue override fixed
- [x] 46 new backend examples pass; full-suite regression diff vs baseline shows zero new failures