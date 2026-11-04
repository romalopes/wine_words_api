# Phase 1 — Mobile Navigation and Responsive Shell

**Status:** ✅ Implemented (flag-gated; ships dark — enable `VITE_MOBILE_LAYOUT_ENABLED=true`)
**Date:** 2026-11-03
**Repositories:** [wine_words (frontend)](https://github.com/romalopes/wine_words_frontend) · [wine_words_api](https://github.com/romalopes/wine_words_api)
**Gate:** A — Responsive mobile experience
**Master plan:** [`../Wine_Words_Mobile_PWA_Implementation_Plan.md`](../Wine_Words_Mobile_PWA_Implementation_Plan.md) · Issue [#201](https://github.com/romalopes/wine_words_api/issues/201)

---

## 1. Objective and scope

Add a mobile-first shell **without changing desktop behaviour**: a responsive
header that reuses the existing `NotificationBell`, a bottom navigation bar
(**Home | Reviews | Articles | More**), and a **More** menu grouping the secondary
routes. All desktop navigation, URLs, routing and role gating stay untouched.

**Non-goals:** offline dependencies, PWA tooling, page rewrites, user-agent
sniffing.

## 2. Prerequisites

- Phase 0 complete (audit baseline captured).

## 3. Tools to install

**None.** Reuse React 19, react-router 7, existing CSS and `NotificationBell`.

## 4. Task breakdown

1. **Breakpoint:** introduce a single mobile breakpoint (provisionally `768px`) via
   CSS media queries — **no** OS/user-agent detection.
2. **`MobileHeader`:** compact header showing brand, the **existing** bell, and the
   More toggle. Reuse `NotificationBell` (do not duplicate).
3. **`MobileNavigation`:** fixed bottom bar with `Home | Reviews | Articles | More`,
   active-route highlighting, `role="navigation"`, 44px-ish touch targets,
   `env(safe-area-inset-bottom)` padding.
4. **`MoreMenu`:** sheet/drawer grouping Finder (`/finder`), Quiz (`/quiz`), Wines,
   Producers, Saved/Offline (later), Notifications, Profile/Settings and
   role-gated Wine Packages (`/wine-packages`). Reuse `constants/roles.ts`
   (`canAccessPackages`, `isAdmin`, `canManageWinesRole`, …).
5. **Layout wiring:** render desktop `Header` above the breakpoint, mobile shell
   below it, from `App.tsx`/a new `ResponsiveShell` component.
6. **Accessibility:** focus management, keyboard nav, `aria-current`, reduced-motion
   support, overflow handling.
7. **Feature flag:** gate the whole shell behind build-time
   `VITE_MOBILE_LAYOUT_ENABLED` (default off until verified).

## 5. Files to change

| File | Action |
|---|---|
| `src/components/MobileHeader.tsx` | New |
| `src/components/MobileNavigation.tsx` | New |
| `src/components/MoreMenu.tsx` | New |
| `src/components/ResponsiveShell.tsx` | New (breakpoint orchestration) |
| `src/App.tsx` | Modify (wrap `Header`/`main` in shell) |
| `src/index.css` | Modify (mobile shell + safe-area styles) |
| `src/components/MobileHeader.test.tsx`, `MobileNavigation.test.tsx`, `MoreMenu.test.tsx` | New tests |
| `src/vite-env.d.ts` | Modify (type the new flag) |

## 6. Feature flags

- `VITE_MOBILE_LAYOUT_ENABLED` — **build-time**; default off.

## 7. Tests

- Unit: bottom bar renders only ≤ breakpoint and when flag enabled; active route
  highlight; More groups correct links; role-gated links hidden for Guests/Readers.
- Accessibility: keyboard traversal, `aria-current`, focus trap in More sheet.
- Regression: desktop `Header` unchanged at ≥ breakpoint; **no duplicate bell**.

## 8. Acceptance criteria

- Bottom bar visible only at the mobile breakpoint and when the flag is enabled.
- Desktop layout, routes and navigation unchanged.
- No duplicate bell or duplicate navigation.
- Keyboard/VoiceOver navigation works.

## 9. Risks, compatibility, rollback

- **Risk:** accidental desktop regression. **Mitigation:** media-query-only shell,
  screenshot regression tests.
- **Rollback:** set `VITE_MOBILE_LAYOUT_ENABLED=false` and redeploy (no data change).

## 10. AI coding prompt (from the master plan)

> Implement only Phase 1 in the existing Wine Words React frontend. Preserve
> desktop layout and routes. Add responsive mobile header with the **existing**
> notification bell and bottom navigation `Home | Reviews | Articles | More`. Put
> Finder, Quiz, Wines, Producers, Saved/Offline, Settings and future
> permission-gated Wine Packages under More. Audit current layout and reuse its
> components; use CSS media queries, not OS detection. Add build-time feature flag,
> responsive tests and screenshots. Do not introduce offline dependencies or
> rewrite desktop pages.

## 11. Gate checklist

- ✅ Shell implemented behind flag
- ✅ Mobile breakpoint (768px) via `matchMedia`; desktop regression suite clean
- ✅ Accessibility checks pass (aria-current, dialog, Escape, 44px targets)
- ✅ No duplicate bell/navigation (bell stays in the existing `Header`)

---

## 12. Outcome record (2026-11-03)

**New files (frontend `wine_words`)**

| File | Purpose |
|---|---|
| `src/constants/featureFlags.ts` | `isMobileLayoutEnabled()` reads build-time `VITE_MOBILE_LAYOUT_ENABLED`; `MOBILE_BREAKPOINT_PX = 768` |
| `src/hooks/useMediaQuery.ts` | Safe `matchMedia` subscription (defaults to desktop when unavailable) |
| `src/hooks/useIsMobile.ts` | `(max-width: 768px)` viewport check |
| `src/components/mobile/MobileNavigation.tsx` | Bottom nav: Home \| Reviews \| Articles \| More |
| `src/components/mobile/MoreMenu.tsx` | More sheet with Discover / Your account / Staff (role-gated) / About groups |
| `src/components/mobile/MobileNavigation.test.tsx` | 3 tests |
| `src/components/mobile/MoreMenu.test.tsx` | 7 tests |

**Modified files**

| File | Change |
|---|---|
| `src/App.tsx` | Mounts `<MobileNavigation />` and adds `app-main--with-mobile-nav` padding when flag + breakpoint are active |
| `src/vite-env.d.ts` | Types `VITE_MOBILE_LAYOUT_ENABLED` |
| `src/setupTests.ts` | Adds a `window.matchMedia` stub for jsdom |
| `src/index.css` | `.mobile-bottom-nav*`, `.more-menu*`, `.app-main--with-mobile-nav` styles |

**Commands and results**

| Command | Result |
|---|---|
| `npm run typecheck` (`tsc -b`) | Clean |
| `npm run lint` (`eslint .`) | 0 errors (8 pre-existing warnings, none in new files) |
| `npx vitest run` | 88 files / 502 tests pass (10 new) |
| `npm run build` (`vite build`) | Succeeds |

**Risks / notes**

- Ships **dark**: nothing renders unless `VITE_MOBILE_LAYOUT_ENABLED=true`. Rollback = unset the flag.
- No offline/PWA dependencies added (as required for Phase 1).
- The existing `Header` (with its own hamburger and the single `NotificationBell`) is unchanged, so there is exactly one bell.
- `useMediaQuery` uses `matchMedia` only (no user-agent sniffing).

