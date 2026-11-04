# Phase 10 — Mobile Notification UX and Preferences

**Status:** ✅ Implemented
**Date:** 2026-11-03
**Repositories:** [wine_words (frontend)](https://github.com/romalopes/wine_words_frontend) · [wine_words_api](https://github.com/romalopes/wine_words_api)
**Gate:** C — Push notifications
**Master plan:** [`../Wine_Words_Mobile_PWA_Implementation_Plan.md`](../Wine_Words_Mobile_PWA_Implementation_Plan.md) · Issue [#201](https://github.com/romalopes/wine_words_api/issues/201)

---

## 1. Objective and scope

Reuse the existing bell and notification API to deliver a mobile-friendly bell,
notification list and opt-in preferences. **Do not invent a messaging feature if
none exists.**

## 2. Prerequisites

- Phase 1 (mobile header + bell), Phase 9 (push capability).

## 3. Tools to install

**None.**

## 4. Task breakdown

1. Reuse bell in the mobile header; responsive notification list.
2. Unread counts, read state, target paths, comment-anchor deep links.
3. Pending-sync indicators (ties into Phase 7 outbox state).
4. Opt-in preferences for follows/comments/replies/**package** events — audit
   whether "messages" actually exist before adding triggers.
5. Optional recent-notification cache for offline reading; refresh on foreground.

## 5. Files to change

| File | Action |
|---|---|
| `src/components/Notifications.tsx` | Modify (mobile list) |
| `src/components/NotificationBell.tsx` | Verify (reuse; no duplicate) |
| `src/components/NotificationPreferences.tsx` | Modify (opt-in) |
| `src/components/MobileHeader.tsx` | Modify (bell placement) |
| Tests beside changed components | Modify/New |

## 6. Tests

- No duplicate bell; unread counts consistent.
- Links resolve (reviews/articles/comments/packages).
- Opt-in/out respected; unavailable feature types not advertised.

## 7. Acceptance criteria

- No duplicate bell; unread counts consistent.
- Links resolve; opt-in/out respected.
- Unavailable feature types not advertised.

## 8. Risks, compatibility, rollback

- **Risk:** advertising nonexistent notification types. **Mitigation:** audit actual
  `Notification::TYPES` before rendering preferences.
- **Rollback:** hide preference UI via flag; bell/list unaffected.

## 9. AI coding prompt (from the master plan)

> Reuse existing Wine Words notification UI and API to deliver a mobile-friendly
> bell/list and settings. Inspect existing notification hooks, unread state and
> routing. Add deep links for reviews/articles/comments and future packages, plus
> push opt-in/preferences only where missing. Preserve existing desktop behavior
> and do not invent a messaging feature if none exists. Add permission and route
> tests.

## 10. Gate checklist

- ⬜ Mobile bell/list responsive
- ⬜ Deep links + unread consistency verified
- ⬜ Preferences match real notification types
