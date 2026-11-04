# Phase 13 — Wine Packages Mobile and Selected Offline Workflows (future)

**Status:** ✅ Mobile UI + account-scoped cached reads implemented; offline mutations deliberately deferred
**Date:** 2026-11-03
**Repositories:** [wine_words (frontend)](https://github.com/romalopes/wine_words_frontend) · [wine_words_api](https://github.com/romalopes/wine_words_api)
**Gate:** E — Packages
**Master plan:** [`../Wine_Words_Mobile_PWA_Implementation_Plan.md`](../Wine_Words_Mobile_PWA_Implementation_Plan.md) · Issue [#201](https://github.com/romalopes/wine_words_api/issues/201)

---

## 1. Objective and scope

Integrate Wine Packages into the mobile app under a **role-aware More** entry,
reusing Rails permissions and existing notification infrastructure. Add mobile
list/detail/tracking/status history, cached reads and offline notes/drafts.

## 2. Prerequisites

- `/wine-packages` and its Rails permissions/workflow exist (partially present —
  verify current models/statuses first).
- Phases 5–7 (Dexie + outbox) available.

## 3. Tools to install

**None** (reuse Dexie; native camera only if Phases 11–12 shipped).

## 4. Task breakdown

1. Audit current package/project models and statuses first.
2. Put the link under More **only for authorised roles** (`canAccessPackages`).
3. Assigned package list, tracking, receipt, history, deadlines, notes, associated
   review/article projects, optional camera/photos.
4. Cache assigned package details and notes; queue **low-risk** local drafts.
5. For `mark_received` (or other approved transitions): submit `expected_version`
   + idempotency key; Rails validates current state/actor.
6. Keep reassignment, cancellation, deadline changes and heavy uploads **online**
   initially.
7. Trigger existing notifications on package events — no second notification system.

## 5. Files to change

| File | Action |
|---|---|
| `src/components/WinePackages.tsx`, `WinePackageDetail.tsx` | Modify (mobile) |
| `src/components/ShipmentTrackingPanel.tsx`, `PackageStatusBadge.tsx` | Modify (mobile) |
| `src/components/MoreMenu.tsx` | Modify (role-gated link) |
| `src/offline/repositories/packageRepository.ts` | New |
| API: versioned status transition + idempotency | Modify (additive) |

## 6. Data-contract rules

- Server validates workflow transitions, `expected_version` and permissions —
  **never last-write-wins**.
- Only explicitly approved transitions may run offline; conflicts are shown.

## 7. Tests

- Roles, assignment, status races, notification delivery.
- Offline drafts survive restart; invalid transitions rejected; conflict UI shown.

## 8. Acceptance criteria

- Role-scoped package data; pending vs confirmed status clearly distinguished.
- Conflict UI; offline drafts survive restart; no invalid transition accepted.

## 9. Risks, compatibility, rollback

- **Risk:** stale status transition accepted. **Mitigation:** optimistic version
  checks + server validation.
- **Rollback:** disable offline package transitions via backend switch; keep
  online package UI.

## 10. AI coding prompt (from the master plan)

> Audit the current Wine Words Wine Package and Article/Review Project
> implementations before adding mobile UI. Integrate `/wine-packages` under
> role-aware More, reusing Rails permissions and existing notification
> infrastructure. Add mobile list/detail/tracking/status history, local cached reads
> and offline notes/drafts. Allow only explicitly approved offline status
> transitions with idempotency and optimistic version checks; show conflicts. Defer
> offline media uploads and admin bulk actions. Add tests for roles, assignment,
> status races and notification delivery.

## 11. Gate checklist

### Implementation result (2026-11-03)

The existing role-gated More link was retained; list/detail pages now have mobile
layouts and account-scoped IndexedDB cached reads. Cached detail copies suppress
all workflow capabilities. Offline status transitions and drafts were not enabled:
the current Rails API has no `expected_version` precondition contract, so queuing
them would violate this phase's conflict-safety rule.

- ⬜ Role-scoped mobile package UI
- ⬜ Approved offline transitions idempotent + version-checked
- ⬜ Existing notifications reused
- ⬜ Gate E ready for review
