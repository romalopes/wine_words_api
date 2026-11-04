# Phase 12 — Capacitor iOS (deferred)

**Status:** ⚠️ Project generated and synced; full Xcode/signing/device verification pending
**Date:** 2026-11-03
**Repositories:** [wine_words (frontend)](https://github.com/romalopes/wine_words_frontend) · [wine_words_api](https://github.com/romalopes/wine_words_api)
**Gate:** D — Native shells
**Master plan:** [`../Wine_Words_Mobile_PWA_Implementation_Plan.md`](../Wine_Words_Mobile_PWA_Implementation_Plan.md) · Issue [#201](https://github.com/romalopes/wine_words_api/issues/201)

---

## 1. Objective and scope

Extend the Capacitor setup to iOS using Xcode on macOS — still one React codebase.

## 2. Prerequisites

- Phase 11 (Capacitor scaffold) complete.

## 3. Tools to install

| Tool | Command / requirement | Notes |
|---|---|---|
| iOS project | `npx cap add ios` · `npx cap open ios` | Requires **Xcode + iOS SDK** (macOS) |
| Optional plugins (defer) | `@capacitor/push-notifications` (APNs) | Add when needed |

**Store fee:** Apple Developer Program ≈ **US$99/year** for device installs/public
distribution. Free local testing may have provisioning restrictions.

## 4. Task breakdown

1. Add iOS project; configure signing.
2. Secure storage; URL schemes / universal links; safe areas; permission strings.
3. APNs native push; foreground/background behaviour.
4. Real-device tests.

## 5. Files to change

| File | Action |
|---|---|
| `ios/` (generated) | New |
| `capacitor.config.ts` | Modify |
| `src/native/adapters/*.ts` | Modify (iOS specifics) |
| `Info.plist` / entitlements | Modify |

## 6. Tests

- iOS app works on a test device.
- Native push deep links, auth and offline persistence tested.
- PWA behaviour remains intact.

## 7. Acceptance criteria

- iOS app works on a test device.
- Native push deep links, auth and offline persistence tested.
- PWA behaviour remains intact.

## 8. Risks, compatibility, rollback

- **Risk:** provisioning/signing friction. **Mitigation:** document free vs paid paths.
- **Rollback:** remove the iOS project; web/PWA unaffected.

## 9. AI coding prompt (from the master plan)

> Extend the existing Wine Words Capacitor setup to iOS using Xcode. Keep one React
> codebase. Audit platform-specific authentication, secure storage, safe areas, deep
> links, APNs notifications and lifecycle. Document free local testing limitations
> and optional paid App Store enrollment. Add simulator and physical-device test
> checklist. Do not regress browser/PWA builds.

## 10. Gate checklist

### Implementation result (2026-11-03)

`ios/` was generated with Capacitor 8.6.0, bundle id `com.winewords.app`, and
the shared production web bundle. `npx cap sync` and `npx cap doctor` pass. The
active developer directory contains Command Line Tools only, not full Xcode, so
signing, simulator, APNs and physical-device verification remain mandatory.

- ⬜ iOS project builds and runs on device
- ⬜ APNs push + deep links verified
- ⬜ Browser/PWA builds unaffected
