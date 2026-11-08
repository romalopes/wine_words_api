# Phase 4 — PWA Installability and Service-Worker Shell

**Status:** ⬜ Not started (planned)
**Date:** 2026-11-03
**Repositories:** [wine_words (frontend)](https://github.com/romalopes/wine_words_frontend) · [wine_words_api](https://github.com/romalopes/wine_words_api)
**Gate:** B — Installable / offline PWA
**Master plan:** [`../Wine_Words_Mobile_PWA_Implementation_Plan.md`](../Wine_Words_Mobile_PWA_Implementation_Plan.md) · Issue [#201](https://github.com/romalopes/wine_words_api/issues/201)

---

## 1. Objective and scope

Make the React app installable as a PWA with an app-shell service worker, manifest
and icons — **without** caching authenticated API JSON. This is the foundation for
offline reads (Phase 6) and Web Push (Phase 9).

## 2. Prerequisites

- Phase 1 mobile shell (install prompt appears in a mobile shell context).
- Cloudflare preview environment verified.

## 3. Tools to install

| Tool | Command | Notes |
|---|---|---|
| `vite-plugin-pwa` (+ Workbox, transitive) | `npm install -D vite-plugin-pwa` | Dev dependency; generates `sw.js` + `manifest.webmanifest` at build time |

**Version gate:** `npm ls vite vite-plugin-pwa` — confirm compatibility with Vite 6.
**Icons:** create original 192×192 and 512×512 PNGs (+ maskable variants) in
`public/` — the current `wine_words_icon.png` is ≈3 KB and too small for a valid
install icon.

## 4. Task breakdown

1. Configure `VitePWA` in `vite.config.ts`: `registerType: "prompt"` (or `autoUpdate`
   after testing), `manifest` (`name`, `short_name`, `start_url: "/"`, `scope: "/"`,
   `display: "standalone"`, `theme_color`, `background_color`, icons).
2. App-shell + static-asset caching via Workbox `globPatterns`; **exclude**
   authenticated API responses (never cache `api/v1/*` JSON).
3. Offline fallback route/page.
4. SW update UX (prompt to reload) and a versioned **unregister/cleanup** path.
5. iOS install guidance ("Add to Home Screen").
6. `index.html`: add `manifest` link + `theme-color` + `apple-touch-icon`.
7. Disable SW registration in test environments; ensure preview testing cannot
   disrupt production scope.

## 5. Files to change

| File | Action |
|---|---|
| `vite.config.ts` | Modify (`VitePWA` config) |
| `index.html` | Modify (manifest/theme-color/apple tags) |
| `public/icon-192.png`, `public/icon-512.png`, `public/icon-maskable-512.png` | New |
| `src/pwa/registerServiceWorker.ts` | New (guarded registration + update/cleanup) |
| `src/components/PwaUpdatePrompt.tsx` | New |
| `src/main.tsx` | Modify (register SW when enabled) |
| `src/vite-env.d.ts` | Modify (`VITE_PWA_ENABLED`) |

## 6. Feature flags

- `VITE_PWA_ENABLED` — build-time; controls registration.

## 7. Tests

- Lighthouse PWA audit (installable, manifest, icons).
- Unit: update prompt renders; unregister path clears caches.
- Verify SW does **not** cache `api/v1` JSON.

## 8. Acceptance criteria

- Installable on supported Android/iOS flows; offline app shell loads after first visit.
- Updates do not strand users on stale assets.
- Existing desktop unaffected.

## 9. Risks, compatibility, rollback

- **Risk:** stale SW. **Mitigation:** versioned SW + explicit unregister/cleanup release.
- **Risk:** caching private data. **Mitigation:** static-only Workbox rules; keep
  authenticated data in Dexie.
- **Rollback:** set `VITE_PWA_ENABLED=false`; ship a cleanup release that unregisters
  the SW and deletes caches.

## 10. AI coding prompt (from the master plan)

> Add a minimal, safely gated PWA to Wine Words using `vite-plugin-pwa` and
> Workbox. First inspect current Vite config and assets. Cache only app shell/static
> assets; do not cache authenticated API JSON. Add manifest, icons, offline
> fallback, install guidance, update/rollback behavior, tests and deployment
> instructions. Keep the existing React app and ensure preview testing cannot
> disrupt production.

## 11. Gate checklist

- ⬜ Manifest + icons valid; installable
- ⬜ App shell loads offline
- ⬜ SW update + rollback paths tested
- ⬜ No authenticated JSON cached
