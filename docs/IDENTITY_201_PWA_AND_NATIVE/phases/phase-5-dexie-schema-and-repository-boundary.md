# Phase 5 — Dexie Schema and Repository Boundary

**Status:** ⬜ Not started (planned)
**Date:** 2026-11-03
**Repositories:** [wine_words (frontend)](https://github.com/romalopes/wine_words_frontend) · [wine_words_api](https://github.com/romalopes/wine_words_api)
**Gate:** B — Installable / offline PWA
**Master plan:** [`../Wine_Words_Mobile_PWA_Implementation_Plan.md`](../Wine_Words_Mobile_PWA_Implementation_Plan.md) · Issue [#201](https://github.com/romalopes/wine_words_api/issues/201)

---

## 1. Objective and scope

Introduce a small, typed, **versioned** local store (Dexie/IndexedDB) and a
repository boundary that later phases consume. Do **not** refactor all pages at
once, and do **not** duplicate Workbox caches.

## 2. Prerequisites

- Phase 4 (PWA shell) merged.
- Understand existing services/hooks (Phase 0 audit).

## 3. Tools to install

| Tool | Command | Notes |
|---|---|---|
| `dexie` | `npm install dexie` | Runtime dependency |
| `dexie-react-hooks` | *(optional)* `npm install dexie-react-hooks` | Only if live queries are wanted; otherwise skip |

## 4. Task breakdown

1. Define versioned tables: cached reviews/articles/comments, recent Finder
   results, quiz question sets/sessions, saved-offline metadata, optional
   notifications snapshot, and the **outbox**.
2. Scope rows by **account**, content visibility and schema version.
3. Cache-age/size policies; use `updated_at` / ETag where available.
4. Repository methods (read/write) — typed, small surface.
5. Logout cleanup: clear account-scoped data (no cross-account leakage).
6. Handle IndexedDB unavailable / quota exceeded gracefully (app stays functional).
7. Consider encryption for highly sensitive data (IndexedDB is not per-user encrypted).

## 5. Files to change

| File | Action |
|---|---|
| `src/offline/db.ts` | New (Dexie schema + versions) |
| `src/offline/types.ts` | New (table row types) |
| `src/offline/repositories/*.ts` | New (repository methods) |
| `src/offline/index.ts` | New (public boundary) |
| `src/contexts/AuthContext.tsx` | Modify (clear offline data on sign-out) |
| `src/offline/*.test.ts` | New |

## 6. Feature flags

- `VITE_OFFLINE_ENABLED` — build-time; keeps online paths working when off.

## 7. Tests

- Schema migration tests (version bumps).
- Account-isolation tests (no leakage across users).
- Quota/unavailable-storage fallbacks.

## 8. Acceptance criteria

- Schema migration + account isolation verified.
- Offline store does not leak content across users.
- App remains functional when IndexedDB is unavailable or quota exceeded.

## 9. Risks, compatibility, rollback

- **Risk:** schema drift. **Mitigation:** explicit Dexie versions + migration tests.
- **Risk:** cross-account leakage. **Mitigation:** account-scoped keys + logout purge.
- **Rollback:** `VITE_OFFLINE_ENABLED=false`; the store is inert when unused.

## 10. AI coding prompt (from the master plan)

> Introduce Dexie incrementally into the existing Wine Words frontend. Audit
> existing API service/hooks and implement a small typed repository layer and
> versioned local schema for reviews, articles, comments, Finder, Quiz, saved
> metadata and future outbox. Do not duplicate Workbox API caches. Add per-account
> isolation, logout cleanup, quota/migration/error handling and tests. Keep online
> paths working behind an offline feature flag.

## 11. Gate checklist

- ⬜ Versioned schema + repositories in place
- ⬜ Account isolation + logout purge tested
- ⬜ Quota/error fallbacks verified
