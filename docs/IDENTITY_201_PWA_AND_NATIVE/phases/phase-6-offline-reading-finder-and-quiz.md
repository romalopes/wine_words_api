# Phase 6 — Offline Reading, Finder and Quiz

**Status:** ✅ Implemented (manual airplane-mode browser check pending)
**Date:** 2026-11-03
**Repositories:** [wine_words (frontend)](https://github.com/romalopes/wine_words_frontend) · [wine_words_api](https://github.com/romalopes/wine_words_api)
**Gate:** B — Installable / offline PWA
**Master plan:** [`../Wine_Words_Mobile_PWA_Implementation_Plan.md`](../Wine_Words_Mobile_PWA_Implementation_Plan.md) · Issue [#201](https://github.com/romalopes/wine_words_api/issues/201)

---

## 1. Objective and scope

Deliver offline **read** support using the Phase 5 repositories: cached
reviews/articles with comments, cached Finder results, and resumable Quiz. **No
offline comment posting yet** (that is Phase 7).

## 2. Prerequisites

- Phase 5 (Dexie repositories).

## 3. Tools to install

**None** (reuse Dexie).

## 4. Task breakdown

1. Cache opened and explicitly **Saved Offline** reviews/articles (+ comments),
   with retention priority.
2. Offline indicators and last-updated/staleness labels.
3. Finder: display recent cached results and client-side filtering of cached sets
   only — never pretend to search the full DB offline.
4. Quiz: download question sets (versioned), persist answers after each question,
   resume across reload/restart, queue completed results if server submission is needed.
5. Respect subscription/paywall rules; re-validate entitlements on reconnect.
6. Treat local quiz scoring as provisional if competitive.

## 5. Files to change

| File | Action |
|---|---|
| `src/offline/repositories/contentRepository.ts` | New/Extend |
| `src/components/ReviewDetail.tsx`, `ArticleDetail.tsx` | Modify (offline read + save) |
| `src/components/Home.tsx` (Finder) | Modify (cached results + stale label) |
| `src/components/Quiz.tsx` | Modify (persist progress, resume) |
| `src/components/OfflineBadge.tsx` | New |
| `src/hooks/useOfflineContent.ts` | New |
| Tests beside changed components | New/Modify |

## 6. Feature flags

- `VITE_OFFLINE_ENABLED`.

## 7. Tests

- Airplane-mode acceptance: saved reading, comment display, cached Finder, quiz
  resume/restart, storage cleanup.
- Uncached content shows an honest offline state (no fake data).

## 8. Acceptance criteria

- Saved reading + comments work offline; staleness shown.
- Cached Finder labelled stale; Quiz resumes across restarts.
- Uncached content shows an honest unavailable message.

## 9. Risks, compatibility, rollback

- **Risk:** paid content cached too liberally. **Mitigation:** entitlement checks +
  retention policy.
- **Rollback:** `VITE_OFFLINE_ENABLED=false` (online paths unchanged).

## 10. AI coding prompt (from the master plan)

> Implement Phase 6 offline **read** support using the Phase 5 repositories. Cache
> opened and explicitly saved Reviews/Articles with comments; show staleness/offline
> labels. Finder should display recent cached results but not pretend to search the
> full database offline. Quiz must persist question-set version, answers and
> progress across reload/restart. Respect subscription restrictions and test
> disconnected scenarios. No offline comment posting yet.

## 11. Gate checklist

- ⬜ Offline reading + comments verified
- ⬜ Finder stale-state correct
- ⬜ Quiz resume/restart verified
