# Phase 0 — Source Audit and Acceptance Baseline

**Status:** ✅ Completed (audit record)
**Date:** 2026-11-03
**Repositories:** [wine_words (frontend)](https://github.com/romalopes/wine_words_frontend) · [wine_words_api](https://github.com/romalopes/wine_words_api)
**Gate:** A — Responsive mobile experience
**Master plan:** [`../Wine_Words_Mobile_PWA_Implementation_Plan.md`](../Wine_Words_Mobile_PWA_Implementation_Plan.md) · Issue [#201](https://github.com/romalopes/wine_words_api/issues/201) · Related [#127](https://github.com/romalopes/wine_words_api/issues/127)

> **Scope:** This phase is read-only. No application behaviour, routes, models or
> assets were changed. It records the *actual* state of both repositories so that
> every later phase references verified code instead of assumptions.

---

## 1. Verified repository state

### Frontend — `wine_words` (branch `main` @ `a5f3845`, working tree clean)

| Area | Verified reality |
|---|---|
| Framework | React 19, Vite 6, TypeScript 6, react-router 7 |
| Styling | Bootstrap + `@heroui/*`, global `src/index.css` and `src/App.css` |
| Auth | **Bearer JWT** persisted in `localStorage` (`wine_words_token`); requests also send `credentials: "include"` |
| API layer | `src/services/apiClient.ts` (`request()`); namespaces composed in `src/services/api.ts` via `create*Api(request)` factories |
| Test-access gate | `X-Test-Access-Token` header added in `api.ts`; redirects to `/test-access` on `test_access_required` |
| Routing | `src/components/AppRoutes.tsx` |
| Navigation | `src/components/Header.tsx`; role helpers in `src/constants/roles.ts` |
| Notification bell | `src/components/NotificationBell.tsx` (calls `notificationsApi.unreadCount()`, subscribes to `onNotificationsChanged`, refetches on focus) |
| Comments | `src/services/commentsApi.ts`, `src/hooks/useComments.ts` (server-truth), `src/components/comments/*` |
| Likes | `src/services/likesApi.ts`, `src/hooks/useLike.ts` (server-truth toggle) |
| Finder | Route `/finder` → `src/components/Home.tsx` |
| Quiz | Route `/quiz` → `src/components/Quiz.tsx` |
| Wine Packages | Route `/wine-packages` (+ detail/form) already present |
| Tests | Vitest + RTL (unit), Playwright (chromium/firefox/accessibility/visual) |

### API — `wine_words_api` (branch `main` @ `ede01c8`, working tree clean)

| Area | Verified reality |
|---|---|
| Framework | Rails 8.1.3, Ruby 3.4.2 |
| Auth | Devise + **devise-jwt** (Bearer); `ApplicationController < ActionController::Base`, `skip_forgery_protection`, `authenticate_user!`, Pundit |
| Background jobs | `config.active_job.queue_adapter = :solid_queue` in `config/environments/production.rb:83`. `solid_queue`, `solid_cache`, `solid_cable` in `Gemfile` |
| Notifications | `Notification` model (TYPES whitelist incl. follow + package types; `notification_event`, `actor`); `Api::V1::NotificationsController` — `index`, `unread_count` (ETag, `private, max-age=30`), `mark_read`, `mark_all_read` |
| Comments | Polymorphic `Comment` on `Wine | Review | Article`, soft delete, single reply level |
| CORS | `rack-cors` with explicit origins + preview regex `https://<name>-wine-words.romalopes.workers.dev` |
| Web Push | **Absent** — no `web-push` gem in `Gemfile`/`Gemfile.lock` |

### Local toolchain (version gate)

- Node **v24.6.0**, npm **11.6.0** — satisfy Vite 6 / Capacitor (Node ≥ 20).
- Ruby **3.4.2**, Rails **8.1.3**.
- `vite-plugin-pwa`, `dexie`, `@capacitor/*`, `web-push` — **not installed** (install per phase).

---

## 2. Corrections to the original plan's assumptions

| Plan assumption | Verified reality |
|---|---|
| "Existing notification bell — retain" | Confirmed present and functional; retain. |
| "TanStack Query optional — do not add unless needed" | **Not installed.** Current data layer is custom hooks; keep it. |
| "Check background job adapter" | Production already uses `solid_queue` (usable for durable push dispatch). |
| "Auth — cookie/JWT" | JWT Bearer via `localStorage` (+ `credentials: include`). Offline work must never persist auth secrets in the outbox. |
| Wine Packages gated under More | `/wine-packages` route already exists (Phase 13 prerequisite partially met). |
| PWA/offline tooling | None present — clean slate for Phases 4–7. |

---

## 3. Gap analysis (what must change)

| Capability | State | Owning phase |
|---|---|---|
| Mobile header + bottom nav | Missing | 1 |
| Mobile-optimised Reviews/Articles/comments/likes | Desktop-only layout | 2 |
| Mobile Finder/Quiz + More menu | Desktop-only layout | 3 |
| Manifest, icons, service worker | Missing | 4 |
| Offline data store (Dexie) | Missing | 5 |
| Offline reading + Quiz resume | Missing | 6 |
| Offline comment/like outbox | Missing | 7 |
| Offline security/quality hardening | Missing | 8 |
| Web Push (VAPID + `web-push` gem) | Missing | 9 |
| Mobile notification UX/preferences | Partial (bell exists) | 10 |
| Capacitor Android/iOS | Missing | 11–12 |
| Wine Packages mobile/offline | Backend + routes partially present | 13 |

---

## 4. Deliverables produced by this phase

- This audit record.
- Phase index added to the master plan.
- One implementation-plan document per phase (`phases/phase-1…13-*.md`).
- Baseline for later regression comparison: desktop layout, routes, test suites unchanged.

---

## 5. Risk register

| Risk | Mitigation |
|---|---|
| Two repos diverge on branch | Frontend work on `feature/mobile-pwa`; API branch only when API changes are needed. |
| Cloudflare preview origin blocked by CORS | Add exact preview origin (regex already covers `*-wine-words.romalopes.workers.dev`). |
| Service worker caches authenticated JSON | Cache only app shell/static assets; keep authenticated data in Dexie (Phase 5). |
| Push double-delivery vs bell | Reuse existing `Notification` rows; push is best-effort, never canonical. |
| Icon assets too small for PWA | Create original 192/512 + maskable icons in Phase 4. |

---

## 6. Gate checklist

- ✅ Both repositories audited and version-gated.
- ✅ Routes, auth, notifications, comments, likes, jobs, CORS, deployment confirmed.
- ✅ Assumptions corrected.
- ✅ Gap analysis and file-change map produced.
- ✅ No application behaviour changed.

**Ready for Phase 1.**

