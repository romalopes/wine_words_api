# Wine Words — Mobile Web, PWA, Offline, Push and Capacitor Implementation Plan

**Status:** Phases 0–10 implemented; Capacitor projects generated/synced; Phase 13 mobile + cached-read scope implemented. Manual PWA/device verification and dependency-audit remediation remain.  
**Date:** 2026-11-01 (plan) · 2026-11-03 (Phase 0 audit)  
**Related issue:** [wine_words_api #127](https://github.com/romalopes/wine_words_api/issues/127) · [Tracking issue #201](https://github.com/romalopes/wine_words_api/issues/201)  
**Repositories:** [Frontend](https://github.com/romalopes/wine_words_frontend) · [Rails API](https://github.com/romalopes/wine_words_api)

> **Verification boundary:** This is an implementation-ready architectural plan, **not a verified file-by-file audit**. Existing notifications and notification bell are reported as implemented by the project owner; retain them. Before coding, inspect current routes, models, jobs, hooks, tests, versions, authentication, and deployment configuration. Do not assume suggested paths or API endpoints already exist.

## Phase index

Phase 0 audited the live repositories (see the audit document). Each numbered phase
below has its own implementation document under [`phases/`](phases/). Implement
**one phase at a time**, run the available checks, and pause for review between
phases.

| Phase | Document | Gate | State |
|---|---|---|---|
| 0 — Source audit and acceptance baseline | [`phases/phase-0-source-audit-and-acceptance-baseline.md`](phases/phase-0-source-audit-and-acceptance-baseline.md) | A | ✅ Complete |
| 1 — Mobile navigation and responsive shell | [`phases/phase-1-mobile-navigation-and-responsive-shell.md`](phases/phase-1-mobile-navigation-and-responsive-shell.md) | A | ✅ Complete |
| 2 — Mobile Reviews, Articles, comments and likes | [`phases/phase-2-mobile-reviews-articles-comments-likes.md`](phases/phase-2-mobile-reviews-articles-comments-likes.md) | A | ✅ Complete |
| 3 — Mobile Finder, Quiz and More | [`phases/phase-3-mobile-finder-quiz-and-more.md`](phases/phase-3-mobile-finder-quiz-and-more.md) | A | ✅ Complete |
| 4 — PWA installability and service-worker shell | [`phases/phase-4-pwa-installability-and-service-worker-shell.md`](phases/phase-4-pwa-installability-and-service-worker-shell.md) | B | ✅ Implemented; manual check pending |
| 5 — Dexie schema and repository boundary | [`phases/phase-5-dexie-schema-and-repository-boundary.md`](phases/phase-5-dexie-schema-and-repository-boundary.md) | B | ✅ Complete |
| 6 — Offline reading, Finder and Quiz | [`phases/phase-6-offline-reading-finder-and-quiz.md`](phases/phase-6-offline-reading-finder-and-quiz.md) | B | ✅ Complete |
| 7 — Offline comments/likes and reliable sync | [`phases/phase-7-offline-comments-likes-and-reliable-sync.md`](phases/phase-7-offline-comments-likes-and-reliable-sync.md) | B | ✅ Complete |
| 8 — Security, quality and release hardening | [`phases/phase-8-security-quality-and-release-hardening.md`](phases/phase-8-security-quality-and-release-hardening.md) | B | ⚠️ Dependency audit pending |
| 9 — Rails notifications with Web Push | [`phases/phase-9-rails-notifications-web-push.md`](phases/phase-9-rails-notifications-web-push.md) | C | ✅ Implemented; live device test pending |
| 10 — Mobile notification UX and preferences | [`phases/phase-10-mobile-notification-ux-and-preferences.md`](phases/phase-10-mobile-notification-ux-and-preferences.md) | C | ✅ Complete |
| 11 — Capacitor Android | [`phases/phase-11-capacitor-android.md`](phases/phase-11-capacitor-android.md) | D | ⚠️ Scaffold/sync complete; SDK test pending |
| 12 — Capacitor iOS | [`phases/phase-12-capacitor-ios.md`](phases/phase-12-capacitor-ios.md) | D | ⚠️ Scaffold/sync complete; Xcode test pending |
| 13 — Wine Packages mobile and offline workflows | [`phases/phase-13-wine-packages-mobile-offline-workflows.md`](phases/phase-13-wine-packages-mobile-offline-workflows.md) | E | ✅ Mobile/cached reads; offline mutations deferred |

> **How to use these documents.** The sections below remain the master reference.
> Before starting any phase, read its phase document for the concrete task list,
> the **tools to install** (installed only when that phase begins), files to
> change, tests, acceptance criteria, risks and rollback. Record the outcome
> (changed files, commands, results) back in the phase document when done.

## 1. Goals and non-goals

Build one React + TypeScript + Vite application serving desktop browsers, mobile browsers, installable PWAs, and later Android/iOS via Capacitor. Retain the existing Rails API and PostgreSQL as canonical data sources. Preserve current desktop behavior. Use only free/open-source libraries and free-to-use platform APIs; avoid paid SDKs and managed sync products. Existing hosting costs and store distribution fees are separate.

**Main mobile navigation:** **Home | Reviews | Articles | More**. The existing notification bell appears in the mobile header. **More** groups Finder (`/finder`), Quiz (`/quiz`), Wines, Producers, Saved/Offline, Notifications, Profile/Settings, and future role-gated Wine Packages (`/wine-packages`). Verify actual production routes before linking.

**MVP:** responsive reading and commenting, existing likes/follows and notification bell, installable PWA, cached reviews/articles and comments, recent Finder results, resumable offline Quiz, safe queued comments/likes, and browser Web Push. **Later:** Capacitor Android/iOS, native push, camera, Wine Packages with offline drafts/selected transitions.

**Out of scope initially:** React Native, second React/Rails repository, complete offline wine catalogue, real-time collaboration, offline bulk admin actions, offline heavy-media uploads, and general-purpose CRDT synchronization.

## 2. Baseline architecture

```text
Desktop / Mobile browser / Installed PWA / Future Capacitor
                       |
          Shared React + Vite app
                       |
          Responsive UI + existing bell
                       |
        Hooks / service / repository layer
             /                    \
        Rails API            Dexie IndexedDB
            |               cache + outbox
    Auth / RBAC / domain       |      |
    notifications / jobs      Sync manager
            |                    |
      PostgreSQL <---- authenticated, idempotent API writes
```

- Use **CSS media queries** for viewport-specific presentation, not OS/user-agent detection. Native platform detection is only for native APIs.
- Preserve desktop navigation; add mobile bottom navigation below a verified breakpoint (provisionally 768px). Use one shared route tree and shared content components.
- Service worker caches app shell/static assets and handles push. Dexie stores structured offline data. Avoid double-caching authenticated JSON in Workbox and Dexie.
- Rails authorizes every synced mutation and remains source of truth for publishing, roles, subscriptions, Follow, comments, and package status.
- Existing in-app notifications are canonical; push is a best-effort additional channel, not a second notification system.

## 3. Free toolchain and costs

| Tool | Why | Cost / decision |
|---|---|---|
| React, TypeScript, Vite, existing CSS | Current frontend | Reuse, free |
| `vite-plugin-pwa` + Workbox | Manifest, SW, app shell, updates | Free OSS; add Phase 4 |
| `dexie` | Structured IndexedDB storage | Free OSS; add Phase 5 |
| TanStack Query | Optional online query caching | Free OSS; **do not add unless current data layer needs it** |
| Browser Push API, Notifications API, VAPID | Browser/PWA notifications | Free platform APIs |
| Ruby `web-push` gem | Send standards-based Web Push | Free OSS; add Phase 9 if absent |
| Rails Active Job / Solid Queue | Durable push dispatch | Free OSS; check existing infrastructure and hosting limits |
| Vitest, React Testing Library, Playwright, RSpec | Tests | Free; reuse if installed |
| Lighthouse / DevTools | Performance, accessibility, PWA checks | Free |
| Capacitor core/CLI/android/ios | Native shells | Free OSS; defer |
| Android Studio/SDK | Android builds and tests | Free |
| Xcode and iOS simulator | iOS builds/tests on macOS | Free |
| Capacitor Push / Camera plugins | Native features | Free OSS; defer |
| FCM/APNs | Native push transport | Standard push delivery free; native setup later |

**Not completely free:** Google Play Console registration (typically US$25 one-time) and Apple Developer Program (typically US$99/year) for public store distribution. No store account is needed for PWA distribution. Free hosting tiers have usage, compute, database, and background-worker limits; verify current provider terms before production. iOS Home Screen Web Push requires supported iOS/iPadOS and an installed web app with permission; do not assume ordinary Safari tabs can receive push. Web Push delivery is not guaranteed. Capacitor is not a trivial one-command release: native auth, secure storage, deep links, permissions, lifecycle, and store compliance require work.

**Version gate:** Before installing, check `node -v`, `npm -v`, Vite, React, Rails, and each package's current compatibility requirements. Use the repo's existing package manager and lockfile; do not migrate package managers as part of this issue.

### Commands (run only in the relevant phase)

```bash
# Frontend: audit first
node -v && npm -v
npm ls vite react @tanstack/react-query vite-plugin-pwa dexie @capacitor/core

# Phase 4: PWA
npm install -D vite-plugin-pwa

# Phase 5: local data
npm install dexie

# Phase 9: Rails API (only if absent)
bundle add web-push

# Phase 11+: native (only after PWA release)
npm install @capacitor/core @capacitor/android @capacitor/ios
npm install -D @capacitor/cli
npx cap init
npx cap add android
npx cap add ios
npm run build
npx cap sync
npx cap open android
npx cap open ios
```

Use official docs for current setup and version requirements: https://vite-pwa-org.netlify.app/ · https://dexie.org/ · https://capacitorjs.com/docs · https://developer.mozilla.org/en-US/docs/Web/API/Push_API · https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/ .

## 4. Non-disruption and rollout controls

1. Branch from current `main` as `feature/mobile-pwa` in frontend; use a separate backend branch only when API changes are needed.
2. Deploy frontend branch to a **separate Cloudflare Pages preview**, verify preview env vars and API CORS. Avoid exposing test push subscriptions to production users.
3. Prefer additive Rails migrations and backward-compatible API fields; no destructive changes to existing notification models or desktop routes.
4. Use feature flags: `VITE_MOBILE_LAYOUT_ENABLED`, `VITE_PWA_ENABLED`, `VITE_OFFLINE_ENABLED`, `VITE_PUSH_NOTIFICATIONS_ENABLED` (Vite flags are **build-time**). Add server-side kill switches for operations that need immediate disabling.
5. Keep existing desktop navigation untouched; scope mobile CSS under a dedicated class/media query. Regression-test 390px, 768px, 1024px, 1440px and keyboard/screen-reader behavior.
6. **Service-worker safety:** register only when enabled; test install/update/unregister, cache versioning, rollback, and stale-client recovery. A flag alone does not remove a previously installed SW; implement an explicit unregister/cleanup path.
7. Roll out separately: mobile UI → PWA shell → offline read → offline writes → push → native. Monitor errors and sync failures via existing Sentry.
8. Use production-like test accounts with different roles/subscriptions; never use production private content in test fixtures.

## 5. Phase-by-phase delivery and AI coding prompts

Each phase requires: (a) audit actual files first; (b) propose minimal changes; (c) implement only that phase; (d) add tests; (e) report changed files, commands, migration notes, risks, and rollback. **Do not invent APIs or replace existing working features.**

### Phase 0 — Source audit and acceptance baseline

**Inspect:** frontend routes/layout/navigation, Reviews, Articles, comments/replies/likes, Finder, Quiz, Follow, existing bell and notification API; Rails notification models/controllers/jobs, authentication, subscriptions/RBAC, background job adapter, CORS, CSP, tests, deployment config, lockfiles. Confirm whether Web Push or service worker already exists. Map actual endpoints and schema. Capture desktop screenshots and current test results.

**Deliverables:** inventory (reuse/extend/add), route map, current notification data flow, exact file-change map, version compatibility, risk register, baseline screenshots and tests, refined estimates.

**Acceptance:** no application behavior changes; every later phase references verified existing code.

**AI prompt:**
> Audit `wine_words_frontend` and `wine_words_api` for issue #127. Do not modify code. Produce a file-by-file map of current navigation, review/article/comments, Finder, Quiz, authentication, Follow, existing notifications/bell, jobs, APIs, tests and deployment. Identify what already exists and precisely what must change for responsive mobile UI, PWA/offline and Web Push. Distinguish confirmed facts from assumptions. Include compatibility checks, migration risks, and an incremental rollout checklist. Do not propose a second app.

### Phase 1 — Mobile navigation and responsive shell

**Tasks:** add reusable `MobileNavigation`, `MobileHeader` (reuse existing bell), `MoreMenu` and responsive layout rules; keep desktop UI; use `Home | Reviews | Articles | More`; role-gate Wine Packages and editorial/admin links; support safe-area insets, focus/keyboard, active-route states, 44px-ish touch targets, reduced motion and overflow. Preserve URLs and routing; no UA sniffing. Hide bottom bar where appropriate for full-screen Quiz only after usability testing.

**Acceptance:** desktop pixel/layout regression acceptable; bottom bar visible only at mobile breakpoint and when flag enabled; no duplicate bell or navigation; accessible keyboard/VoiceOver navigation.

**AI prompt:**
> Implement only Phase 1 in the existing Wine Words React frontend. Preserve desktop layout and routes. Add responsive mobile header with the **existing** notification bell and bottom navigation `Home | Reviews | Articles | More`. Put Finder, Quiz, Wines, Producers, Saved/Offline, Settings and future permission-gated Wine Packages under More. Audit current layout and reuse its components; use CSS media queries, not OS detection. Add build-time feature flag, responsive tests and screenshots. Do not introduce offline dependencies or rewrite desktop pages.

### Phase 2 — Mobile Reviews, Articles, comments and likes

**Tasks:** adapt list cards, article/review detail, image ratios, reading typography, filters/search, pagination, comments/replies, likes, links and subscription paywalls. Reuse existing API/hooks. Ensure deep-linkable comment targets. Audit rich-text sanitization and images.

**Acceptance:** browsing/reading/commenting works at phone widths and desktop unchanged; server authorization still enforced; tests cover logged-out and restricted users.

**AI prompt:**
> Inspect current Reviews, Articles, comments/replies and likes components and their API hooks. Make them mobile-friendly with minimal component changes and responsive styles, while preserving desktop behavior, routes, permissions and subscription gates. Include comment deep-link targets, accessible touch controls and regression tests. Do not implement offline writes yet.

### Phase 3 — Mobile Finder, Quiz and More

**Tasks:** mobile filter drawer/bottom sheet for `/finder`, usable result cards, responsive `/quiz` question controls and progress, More grouping, route preservation, loading/error states.

**Acceptance:** Finder and Quiz usable at 320–430px, keyboard accessible, existing business logic preserved.

**AI prompt:**
> Audit current `/finder` and `/quiz` pages and APIs. Adapt existing UI for mobile: touch-friendly Finder filters, readable results, large Quiz answer targets and persistent navigation where appropriate. Build More menu from existing routes and role checks. Do not fork business logic or add offline caching in this phase. Add viewport and accessibility tests.

### Phase 4 — PWA installability and service-worker shell

**Tasks:** add `vite-plugin-pwa` and manifest with icons (create original app assets), `start_url`, `scope`, `display: standalone`, theme/background colors; configure app-shell/static caching, offline fallback, SW update UX, installation guidance (iOS Add to Home Screen), push-ready SW architecture. Avoid caching private API responses in Workbox. Handle Cloudflare preview scope/origin and disable SW in test environments as appropriate.

**Acceptance:** installable on supported Android/iOS flows; offline app shell loads after first visit; updates do not strand users on stale assets; existing desktop unaffected.

**AI prompt:**
> Add a minimal, safely gated PWA to Wine Words using `vite-plugin-pwa` and Workbox. First inspect current Vite config and assets. Cache only app shell/static assets; do not cache authenticated API JSON. Add manifest, icons, offline fallback, install guidance, update/rollback behavior, tests and deployment instructions. Keep the existing React app and ensure preview testing cannot disrupt production.

### Phase 5 — Dexie schema and repository boundary

**Tasks:** install Dexie; define versioned tables for cached reviews/articles/comments, recent Finder results, quiz question sets/sessions, saved-offline metadata, notifications snapshot (optional), and outbox. Scope by account, content visibility and schema version. Use `updated_at`, ETag/version where available, cache age/size policies and explicit downloads. Design repository methods; do not refactor all pages at once. Consider encrypted storage for highly sensitive data; browser IndexedDB is not automatically encrypted per user. Clear account-specific data on logout; explain limits of offline entitlement revocation.

**Acceptance:** schema migration and account-isolation tests; offline store does not leak content across users; app remains functional when IndexedDB is unavailable/quota exceeded.

**AI prompt:**
> Introduce Dexie incrementally into the existing Wine Words frontend. Audit existing API service/hooks and implement a small typed repository layer and versioned local schema for reviews, articles, comments, Finder, Quiz, saved metadata and future outbox. Do not duplicate Workbox API caches. Add per-account isolation, logout cleanup, quota/migration/error handling and tests. Keep online paths working behind an offline feature flag.

### Phase 6 — Offline reading, Finder and Quiz

**Tasks:** cache opened reviews/articles and comments, explicit Save Offline with retention priority; offline indicators and stale timestamps; cached Finder queries/results and client-side filtering of cached result sets only; download quiz questions and versioned answer sets, save after each answer, resume across restarts, queue completed results if server submission is needed. Validate paid-content caching policy and permissions on reconnection. Treat local quiz scoring as provisional if competitive.

**Acceptance:** airplane-mode acceptance tests for saved reading, comments display, cached Finder, quiz resume/restart, storage cleanup; uncached content shows honest offline state.

**AI prompt:**
> Implement Phase 6 offline **read** support using the Phase 5 repositories. Cache opened and explicitly saved Reviews/Articles with comments; show staleness/offline labels. Finder should display recent cached results but not pretend to search the full database offline. Quiz must persist question-set version, answers and progress across reload/restart. Respect subscription restrictions and test disconnected scenarios. No offline comment posting yet.

### Phase 7 — Offline comments/likes and reliable sync

**Tasks:** define durable outbox operations with client operation UUID, idempotency key, account scope, dependency ordering, retry count, status, error and timestamp. Backend idempotency storage/check for creates; comments require reauthorization on sync. Likes reconcile desired final state; edits use optimistic version checks where supported. Foreground startup, reconnect, visibility-resume and manual retry; browser Background Sync only as enhancement. Do not silently drop writes; show pending/sent/failed/conflict states. Avoid storing auth secrets in outbox. Ensure replay handles network timeout after successful server commit.

**Acceptance:** no duplicate comments under retries; unlike/like toggles reconcile; offline comment drafts survive restart; expired permissions preserve draft but reject publish; failed writes are visible.

**AI prompt:**
> Implement safe offline comment and like writes for Wine Words, reusing existing Rails endpoints and permission rules. First audit actual API schemas. Add a durable Dexie outbox with UUID/idempotency keys, retry/backoff, account scoping, UI pending/error states, reconnect and foreground sync. Add minimal Rails idempotency support where needed; likes should reconcile desired state and comments should not duplicate on retry. Test network timeouts, logout, expired session, role changes and conflict handling. Do not implement generic last-write-wins or offline admin actions.

### Phase 8 — Security, quality and release hardening

**Tasks:** auth/session behavior while offline, subscription entitlements and revoked access, multi-account device, cache purge, XSS/HTML sanitization, CSP, CORS, private images, offline telemetry without sensitive payloads, PWA update migrations, performance and accessibility. Playwright browser contexts at mobile widths plus real device smoke tests. Build an offline scenario matrix and rollback plan.

**Acceptance:** no cross-account leakage; no bypass of Rails authorization; offline write rejection is surfaced; no desktop regressions; performance and accessibility baselines agreed.

**AI prompt:**
> Perform a focused security/reliability audit of Wine Words PWA and offline functionality. Test logout/account switching, subscription expiry, cache invalidation, XSS, auth refresh, outbox retries, SW updates, storage quota, offline/online transitions, accessibility and desktop regression. Fix issues without changing core domain behavior. Provide a production release checklist, monitoring signals and rollback procedure.

### Phase 9 — Extend existing Rails notifications with Web Push

**Tasks:** inspect current notification model, API, bell, Follow propagation and job adapter. **Reuse existing records**; add device subscription endpoints/storage only if absent. Register VAPID browser subscriptions with permission prompted by explicit user action. Send push via free Ruby `web-push`, queued through durable jobs; remove invalid endpoints, rate-limit/group noisy events, dedupe recipient/event across multiple follows. Implement SW `push` and `notificationclick` handlers with safe deep links. No private content in lock-screen payload. Keep push as best-effort; bell/history remains canonical. Use free standard Web Push, not mandatory paid OneSignal.

**Acceptance:** comment/reply, followed-content and later package notifications appear in bell regardless of push; supported installed PWA receives push while app closed; disabled/unsupported permission handled gracefully; no duplicate notification records.

**AI prompt:**
> Audit the **already implemented** Wine Words backend notifications and frontend bell. Do not recreate them. Identify existing Follow event generation, unread APIs and jobs. Add only missing Web Push capability: VAPID subscription registration, endpoint lifecycle, Rails delivery adapter, service-worker push/click handling and permission UI. Deduplicate event recipients, avoid leaking private text, and retain in-app notification history as source of truth. Test iOS Home Screen PWA constraints, Android and desktop supported browsers, invalid subscriptions and retries. Keep all libraries free.

### Phase 10 — Mobile notification UX and preferences

**Tasks:** reuse bell in mobile header; responsive notification list, unread counts, read state, notification target paths, comment anchor deep links, pending sync indicators, and opt-in preferences for follows/comments/replies/messages/package events. Audit whether messaging actually exists before adding message triggers. Optional recent notification cache for offline reading; refresh on foreground.

**Acceptance:** no duplicate bell; unread counts consistent; links resolve; opt-in/out respected; unavailable feature types not advertised.

**AI prompt:**
> Reuse existing Wine Words notification UI and API to deliver a mobile-friendly bell/list and settings. Inspect existing notification hooks, unread state and routing. Add deep links for reviews/articles/comments and future packages, plus push opt-in/preferences only where missing. Preserve existing desktop behavior and do not invent a messaging feature if none exists. Add permission and route tests.

### Phase 11 — Capacitor Android (deferred)

**Tasks:** check current Capacitor/Node compatibility; add Capacitor in same frontend repo, Android project, environment-specific API base URL/CORS, deep links, secure native auth storage, splash/icons, app lifecycle/reconnect, push via FCM where needed, Android permissions, local builds and physical device tests. Distinguish web SW from native container and avoid duplicate push registrations.

**Acceptance:** existing web/PWA still builds; Android launches, authenticates, navigates, caches content, syncs safely and opens notification deep links.

**AI prompt:**
> Add Capacitor Android packaging to the existing Wine Words React/Vite repository, **only after the PWA is stable**. Audit versions and auth first. Reuse routes and components, isolate native plugins behind adapters, configure Android build, secure credentials, lifecycle/reconnect, deep links and optional FCM push. Do not create a separate React app. Document all local SDK steps and free vs paid distribution costs; test on emulator and real device.

### Phase 12 — Capacitor iOS (deferred)

**Tasks:** add iOS project using Xcode on macOS; configure signing, secure storage, URL schemes/universal links, safe areas, permission strings, APNs native push, foreground/background behavior, and real-device tests. Free local testing may have provisioning restrictions; public App Store release requires Apple Developer Program.

**Acceptance:** iOS app works on a test device; native push deep links, auth and offline persistence tested; PWA behavior remains intact.

**AI prompt:**
> Extend the existing Wine Words Capacitor setup to iOS using Xcode. Keep one React codebase. Audit platform-specific authentication, secure storage, safe areas, deep links, APNs notifications and lifecycle. Document free local testing limitations and optional paid App Store enrollment. Add simulator and physical-device test checklist. Do not regress browser/PWA builds.

### Phase 13 — Wine Packages mobile and selected offline workflows (future)

**Prerequisite:** `/wine-packages` and its Rails permissions/workflow exist. Audit current package/project models and statuses first. Put link under More only for authorised roles. Implement assigned package list, tracking, receipt, history, deadlines, notes, associated review/article projects, optional camera/photos. Cache assigned package details and notes; queue low-risk local drafts. For `mark_received` or other approved transitions, submit `expected_version` and idempotency key; Rails validates current state/actor. Keep reassignment, cancellation, deadline changes, and heavy uploads online initially. Trigger existing notifications on package events; do not create a second notification system.

**Acceptance:** role-scoped package data; pending updates clearly distinguished from confirmed status; conflict UI; offline drafts survive restart; no invalid transition accepted.

**AI prompt:**
> Audit the current Wine Words Wine Package and Article/Review Project implementations before adding mobile UI. Integrate `/wine-packages` under role-aware More, reusing Rails permissions and existing notification infrastructure. Add mobile list/detail/tracking/status history, local cached reads and offline notes/drafts. Allow only explicitly approved offline status transitions with idempotency and optimistic version checks; show conflicts. Defer offline media uploads and admin bulk actions. Add tests for roles, assignment, status races and notification delivery.

## 6. Data contracts and synchronization safeguards

**Suggested local schema (adjust to actual Rails JSON):**

```typescript
interface OutboxOperation {
  id: string;                 // local UUID
  idempotencyKey: string;     // server-recognized
  accountId: string;
  entityType: 'comment' | 'like' | 'quiz_result' | 'wine_package';
  entityId?: string;
  action: string;
  payload: unknown;
  expectedVersion?: string | number;
  createdAt: string;
  attempts: number;
  status: 'pending' | 'syncing' | 'failed' | 'conflict';
  lastError?: string;
}
```

**Rules:**
- Every mutation is authenticated and reauthorized by Rails at sync time.
- Server persists idempotency outcomes long enough to cover realistic retries; scope keys by actor and operation.
- Comments: create once; edit with version checks; keep failed drafts.
- Likes: reconcile final desired state instead of replaying contradictory toggles.
- Quiz: persist question-set/version and local progress; server validates any competitive result.
- Packages: server validates workflow transitions, expected version and permissions; never last-write-wins.
- Cached content: show last-updated timestamp; refresh on reconnect; protect private/paid data; invalidate when entitlements change on next successful check.
- Push: never treated as guaranteed delivery or the canonical data source.
- Service worker: never blindly cache all authenticated responses.

## 7. API inventory to confirm in Phase 0

| Domain | Confirm current API | Potential additive change |
|---|---|---|
| Reviews / Articles | list, detail, update timestamps, comments | Conditional fetch/version metadata if useful |
| Comments | create/edit/delete, auth, replies | Idempotency key support |
| Likes | toggle/desired state | Idempotent set-like endpoint if needed |
| Finder | query params, pagination, result schema | None for cached-result MVP |
| Quiz | questions, sessions, submissions | Idempotent result submission if applicable |
| Follow | polymorphic follow targets, propagation | Event deduping/aggregation if missing |
| Notifications | existing bell API, unread/read, jobs | Push endpoint registration and delivery |
| Auth | cookie/JWT, refresh, logout, subscription | Native credential handling; offline policy |
| Wine Packages | states, assignments, history, projects | Versioned status actions later |

Do not create new API endpoints when an existing endpoint can be safely extended without breaking clients.

## 8. Test and acceptance matrix

| Scenario | Required result |
|---|---|
| Desktop 1440px | Existing layout, nav, content, bell unchanged |
| Mobile 390px | Bottom navigation Home/Reviews/Articles/More; existing bell visible |
| Logged out | Public content and permitted routes work; restricted actions gated |
| Paid content offline | Only allowed cached data; clear entitlement/staleness policy |
| Previously opened article/review offline | Read with cached comments |
| Uncached review offline | Clear unavailable message, no fake data |
| Finder offline | Cached/recent results labelled stale |
| Quiz offline/restart | Answers and progress restored |
| Comment offline/restart | Draft/pending state retained |
| Comment retry after response loss | Exactly one server comment |
| Like then unlike offline | Final intended state synced |
| Expired auth / revoked role | Server rejects action, draft preserved, user informed |
| Switch accounts | No cached data/outbox cross-account leakage |
| SW update | New version installs safely; rollback documented |
| Browser push denied | Bell still works; no repeated prompts |
| Follow event | One in-app notification per recipient/event, push if opted in |
| Native push (later) | Opens correct authenticated target |
| Package concurrent status change | Server rejects stale transition; user sees conflict |

## 9. Release gates, estimates, and rollback

**Gate A:** Phases 0–3 (responsive mobile experience). **Gate B:** Phases 4–8 (installable/offline PWA). **Gate C:** Phases 9–10 (push). **Gate D:** Phases 11–12 (native). **Gate E:** Phase 13 (packages).

Indicative engineering effort **after audit**, not a promise: Gate A ~1–3 weeks; Gate B ~3–6 weeks; Gate C ~1–3 weeks; Gate D ~2–4 weeks; packages depend on backend readiness. Scope and test coverage drive variance.

**Rollbacks:** disable UI features by deploy/flag; disable offline write processing via backend switch; leave queued drafts intact until recoverable; stop push dispatch without deleting in-app notifications; unregister/replace problematic SW with a versioned cleanup release. Do not roll back additive database migrations blindly.

## 10. Production readiness checklist

- [ ] Desktop screenshots and regression tests approved
- [ ] Mobile navigation, touch, accessibility and safe areas verified
- [ ] PWA manifest, icons, install and update flow tested
- [ ] Offline cache quota, schema migration and cleanup tested
- [ ] Account isolation, auth expiry, paywall and privacy reviewed
- [ ] Outbox retry, deduplication, conflict and failure UI tested
- [ ] Existing bell and notification API reused
- [ ] Web Push permission, subscription lifecycle and payload privacy tested
- [ ] Durable jobs and hosting resource requirements reviewed
- [ ] Cloudflare preview/prod environment separation verified
- [ ] Monitoring, error budgets, rollback and support instructions documented
- [ ] Real iOS and Android PWA device smoke tests completed
- [ ] Native build/store costs reviewed only when native release begins

## 11. Master orchestration prompt

> You are implementing Wine Words issue #127 across the existing `wine_words_frontend` and `wine_words_api` repositories. Build **one React/Vite application** for desktop, mobile, PWA and later Capacitor. Preserve desktop behavior and existing Rails authentication, RBAC, subscription controls, Follow, notifications, notification bell, comments and business logic. Mobile navigation is **Home | Reviews | Articles | More**; Finder, Quiz and future role-gated Wine Packages belong under More. Use **only free/open-source components**, avoid paid sync/push SDKs, and keep production safe through preview builds, feature flags, additive migrations and tests. **First perform Phase 0 source audit** and identify actual files, routes and existing features; do not assume missing features. Then implement exactly one numbered phase at a time, pausing for review between phases. For each phase: give a precise change plan, implement minimal code, add tests, run available checks, list changed files/commands and report risks, compatibility, migration and rollback. Do not add React Native, a second frontend, duplicate notifications or a general-purpose sync engine. Treat Rails as canonical and use idempotency plus operation-specific conflict policies for offline writes.

---

**Recommended starting action:** Complete **Phase 0** and **Phase 1** first. Do not install Dexie, PWA tooling or Capacitor until their respective phases. This minimises disruption and makes every subsequent change evidence-based.
