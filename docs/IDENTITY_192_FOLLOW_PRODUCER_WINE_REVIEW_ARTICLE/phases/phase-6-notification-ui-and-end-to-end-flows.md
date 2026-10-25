# Phase 6 — Generalized Notification UI (contents live in the phase-5 file; this copy covers the phase-6 backend/frontend sections)

## Backend

- `NotificationSerializer` — adds `notification_event_id`, `event_type`, `actor_name`, `target_path`, `target_label`, `delivered_at`; legacy package fields unchanged.
- `NotificationsController#index` — eager loads `notification_event: :actor`; the `delivered` scope now covers in-app visibility for both kinds.
- `Notifications.test.tsx` — follow notification renders its message, a link to `target_path` and no "not sent yet" noise.

## Gate: Phase 6 Complete

- [x] Follow deliveries appear in the existing notifications feed
- [x] Backward compatibility preserved (43 legacy notification specs pass)
- [x] Unread badge and mark-read flows unchanged

**Status:** Completed  
**Date:** 2026-10-25  

---

## New files

| File | Purpose |
|---|---|
| `src/types/follow.ts` | `FollowableType`, `Follow`, `FollowStatus`, `FollowStatuses`, `FollowWritePayload` |
| `src/services/followsApi.ts` | API client: `list` (type filter + pagination), `follow` (id/idempotent), `unfollow`, `status`, `statuses`, `preferences`, `updatePreferences` |
| `src/components/FollowButton.tsx` | Reusable follow/unfollow toggle; anonymous users get a sign-in link; state loaded from `GET /follows/status` and confirmed by API responses; error display with rollback |
| `src/components/FollowButton.test.tsx` | 6 tests: state load, following state, follow (slug payload), unfollow by id, error rollback, anonymous sign-in prompt |
| `src/components/Following.tsx` | Following page: All/Producers/Wines/Reviews/Articles filters, pagination, optimistic unfollow with rollback, empty/error/loading states, signed-out prompt |
| `src/components/Following.test.tsx` | 7 tests: list + links, type filter, optimistic unfollow, failure rollback + reload, empty state, sign-in prompt, pagination |

## Integrations

- `ReviewDetail.tsx` — `FollowButton kind="Review"` in the byline actions (beside LikeButton)
- `ArticleDetail.tsx` — `FollowButton kind="Article"` in the byline actions
- `WineDetail.tsx` — `FollowButton kind="Wine"` in the DetailHero actions
- `ProducerDetail.tsx` — `FollowButton kind="Producer"` inside DetailHero
- `AppRoutes.tsx` — `/following` route
- `Header.tsx` — "Following" nav link next to the notification bell
- `services/api.ts` — `followsApi` exported
- `index.css` — `.follow-button*` (pill style matching `.like-button`) and `.following-page*` styles

## Validation

- `npm run typecheck` — clean
- Component suites: 13 new tests pass
- Full frontend suite: only the 4 pre-existing baseline failures remain (ApiHealth ×2, ProducerDetail membership, Reviews card — verified identical to `main` via stash baseline)
- `npm run lint` — 0 errors (warnings all pre-existing)
- `npm run build` — succeeds

---

# Phase 6 — Generalized Notification UI

**Status:** Completed  
**Date:** 2026-10-25  

## Backend

- `NotificationSerializer` — adds `notification_event_id`, `event_type`, `actor_name`, `target_path`, `target_label`, `delivered_at`; legacy package fields unchanged (backward compatible).
- `NotificationsController#index` — eager loads `notification_event: :actor`; `delivered` scope now means in-app visible (either channel), so follow deliveries appear in the same feed as package reminders. `unread_count` and mark-read endpoints work unchanged for both kinds.

## Frontend

- `src/types/notification.ts` — 11 new notification types + the follow fields.
- `src/components/Notifications.tsx` — follow-based rows render a link to `target_path` (target_label) in the Package column and an actor/event status label ("Comment by X" / "By X" / "In-app") instead of the package badge; "not sent yet" is only shown for package rows (follow notifications are in-app only).

## Tests

- `Notifications.test.tsx` — new case: follow notification renders message, link to `/reviews/:slug`, and no "not sent yet" noise (8 tests total, all pass)
- Backend `follow_notifications_flow_spec.rb` — feed integration asserts `notification_type`, `target_path`, `target_label`, unread state