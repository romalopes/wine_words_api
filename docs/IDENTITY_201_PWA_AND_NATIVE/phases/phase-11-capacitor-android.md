# Phase 11 — Capacitor Android (deferred)

**Status:** ⚠️ Project generated and synced; Android SDK/emulator/device verification pending
**Date:** 2026-11-03
**Repositories:** [wine_words (frontend)](https://github.com/romalopes/wine_words_frontend) · [wine_words_api](https://github.com/romalopes/wine_words_api)
**Gate:** D — Native shells
**Master plan:** [`../Wine_Words_Mobile_PWA_Implementation_Plan.md`](../Wine_Words_Mobile_PWA_Implementation_Plan.md) · Issue [#201](https://github.com/romalopes/wine_words_api/issues/201)

---

## 1. Objective and scope

Package the **existing** React/Vite app as an Android app with Capacitor — one
codebase, no second React app. This phase starts only after the PWA (Gates A–C)
is stable.

## 2. Prerequisites

- PWA + offline + push stable (Phases 4–10).
- Capacitor/Node compatibility audited first.

## 3. Tools to install

| Tool | Command | Notes |
|---|---|---|
| Capacitor runtime | `npm install @capacitor/core @capacitor/android @capacitor/ios` | Runtime deps |
| Capacitor CLI | `npm install -D @capacitor/cli` | Dev dep |
| Init + Android project | `npx cap init` · `npx cap add android` · `npm run build` · `npx cap sync` · `npx cap open android` | |
| Optional plugins (defer) | `@capacitor/push-notifications`, `@capacitor/camera` | Add only when needed |

**Local SDK (free):** Android Studio + Android SDK + JDK (bundled with Android
Studio). **Store fee:** Google Play Console ≈ **US$25** one-time (public
distribution only).

## 4. Task breakdown

1. Check current Capacitor/Node compatibility; audit native auth first.
2. Add Android project; configure environment-specific API base URL + CORS.
3. Deep links; secure native auth storage (isolate plugins behind adapters).
4. Splash/icons; app lifecycle + reconnect behaviour.
5. Push via FCM where needed; **distinguish web SW from native container** and
   avoid duplicate push registrations.
6. Android permissions; local builds + physical-device tests.

## 5. Files to change

| File | Action |
|---|---|
| `package.json` | Modify (Capacitor deps + scripts) |
| `capacitor.config.ts` | New |
| `android/` (generated) | New |
| `src/native/adapters/*.ts` | New (plugin isolation) |
| `.env` / build config | Modify (per-environment API URL) |

## 6. Tests

- Existing web/PWA still builds.
- Android launches, authenticates, navigates, caches content, syncs safely.
- Notification deep links open the correct authenticated target.
- Emulator + real device.

## 7. Acceptance criteria

- Web/PWA builds unaffected.
- Android app authenticates, navigates, caches, syncs and opens notification deep
  links.

## 8. Risks, compatibility, rollback

- **Risk:** duplicate push registrations. **Mitigation:** web vs native channel split.
- **Risk:** insecure credential storage. **Mitigation:** native secure storage adapter.
- **Rollback:** remove the Android project/scripts; web/PWA unaffected.

## 9. AI coding prompt (from the master plan)

> Add Capacitor Android packaging to the existing Wine Words React/Vite repository,
> **only after the PWA is stable**. Audit versions and auth first. Reuse routes and
> components, isolate native plugins behind adapters, configure Android build,
> secure credentials, lifecycle/reconnect, deep links and optional FCM push. Do not
> create a separate React app. Document all local SDK steps and free vs paid
> distribution costs; test on emulator and real device.

## 10. Gate checklist

### Implementation result (2026-11-03)

`android/` was generated with Capacitor 8.6.0, app id `com.winewords.app`, and
the shared production web bundle. `npx cap sync` and `npx cap doctor` pass. This
machine has no Java runtime/Android SDK, so Gradle, emulator and physical-device
verification remain mandatory.

- ⬜ Android project builds and runs
- ⬜ Auth/offline/sync verified on device
- ⬜ Deep links + push channel separation verified
