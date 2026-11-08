# Phase 9 — Extend Existing Rails Notifications with Web Push

**Status:** ✅ Implemented (live VAPID/device delivery pending)
**Date:** 2026-11-03
**Repositories:** [wine_words_api](https://github.com/romalopes/wine_words_api) · [wine_words (frontend)](https://github.com/romalopes/wine_words_frontend)
**Gate:** C — Push notifications
**Master plan:** [`../Wine_Words_Mobile_PWA_Implementation_Plan.md`](../Wine_Words_Mobile_PWA_Implementation_Plan.md) · Issue [#201](https://github.com/romalopes/wine_words_api/issues/201)

---

## 1. Objective and scope

Add standards-based **Web Push** on top of the **already implemented** notification
system. Reuse existing `Notification` records; push is best-effort and never a
second notification system. The bell/history stays canonical.

## 2. Prerequisites

- Phase 4 (service worker) merged.
- Notification model/controller/bell confirmed (Phase 0 audit).

## 3. Tools to install

| Tool | Command | Notes |
|---|---|---|
| Ruby `web-push` gem | `bundle add web-push` | **Absent today** — verified in `Gemfile`/`Gemfile.lock` |

Generate VAPID keys (once, stored as server secrets):

```bash
bundle exec rails runner "require 'web_push'; puts WebPush.generate_key"
# or: bundle exec web-push generate-vapid-keys
```

Durable dispatch uses the existing **Solid Queue** (`production.rb` already sets
`:solid_queue`) — no new job infra needed.

## 4. Task breakdown

1. Audit existing notification model/API/bell + Follow propagation and job adapter.
2. Add **device subscription** endpoints/storage (only if absent): create/delete
   browser subscriptions (endpoint + keys), scoped to the user.
3. Register VAPID subscriptions with permission prompted by explicit user action.
4. Send push via `web-push`, queued through durable jobs; remove invalid endpoints;
   rate-limit/group noisy events; dedupe recipient/event across multiple follows.
5. SW `push` + `notificationclick` handlers with safe deep links.
6. **No private content** in lock-screen payload; push best-effort; in-app history
   remains canonical.

## 5. Files to change

| File | Action |
|---|---|
| `Gemfile` / `Gemfile.lock` | Modify (`web-push`) |
| `db/migrate/*_create_push_subscriptions.rb` | New (additive) |
| `app/models/push_subscription.rb` | New |
| `app/controllers/api/v1/push_subscriptions_controller.rb` | New |
| `app/jobs/notifications/web_push_delivery_job.rb` | New |
| `config/routes.rb` | Modify (subscription routes) |
| Frontend `src/services/pushApi.ts`, `src/pwa/sw-push.ts`, `src/components/PushOptIn.tsx` | New |

## 6. API contract (additive)

```
POST   /api/v1/push_subscriptions      # register a browser subscription
DELETE /api/v1/push_subscriptions/:id  # unregister
GET    /api/v1/push_subscriptions      # list (own)
```

## 7. Tests

- Comment/reply, followed-content and later package notifications appear in the
  bell regardless of push.
- Supported installed PWA receives push while the app is closed.
- Disabled/unsupported permission handled gracefully; no duplicate records.
- Invalid subscriptions pruned; retries safe.

## 8. Acceptance criteria

- Bell/history unchanged and canonical.
- Push delivered on supported installed PWAs; graceful otherwise.
- No duplicate notification records; no private content in payloads.

## 9. Risks, compatibility, rollback

- **Risk:** iOS push limitations. **Mitigation:** test iOS Home Screen PWA; document
  constraints (installed app only).
- **Rollback:** stop push dispatch (leave queued in-app notifications intact); keep
  `Notification` rows.

## 10. AI coding prompt (from the master plan)

> Audit the **already implemented** Wine Words backend notifications and frontend
> bell. Do not recreate them. Identify existing Follow event generation, unread
> APIs and jobs. Add only missing Web Push capability: VAPID subscription
> registration, endpoint lifecycle, Rails delivery adapter, service-worker
> push/click handling and permission UI. Deduplicate event recipients, avoid
> leaking private text, and retain in-app notification history as source of truth.
> Test iOS Home Screen PWA constraints, Android and desktop supported browsers,
> invalid subscriptions and retries. Keep all libraries free.

## 11. Gate checklist

- ⬜ `web-push` + VAPID configured
- ⬜ Subscription lifecycle + pruning tested
- ⬜ Bell remains canonical; no duplicates
- ⬜ Gate C ready for review
