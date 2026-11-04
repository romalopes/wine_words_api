# Phase 8 — Security, Quality and Release Hardening

**Status:** ⚠️ Implemented; dependency-audit remediation remains a release blocker
**Date:** 2026-11-03
**Repositories:** [wine_words (frontend)](https://github.com/romalopes/wine_words_frontend) · [wine_words_api](https://github.com/romalopes/wine_words_api)
**Gate:** B — Installable / offline PWA
**Master plan:** [`../Wine_Words_Mobile_PWA_Implementation_Plan.md`](../Wine_Words_Mobile_PWA_Implementation_Plan.md) · Issue [#201](https://github.com/romalopes/wine_words_api/issues/201)

---

## 1. Objective and scope

Audit and harden the PWA + offline surface before enabling offline writes in
production: auth/session while offline, entitlements, multi-account devices, cache
purge, XSS/sanitization, CSP/CORS, private images, offline telemetry, SW update
migrations, performance and accessibility.

## 2. Prerequisites

- Phases 4–7 implemented.

## 3. Tools to install

**None.** Reuse Vitest/RTL/Playwright + Lighthouse/DevTools. Playwright runs at
mobile widths.

## 4. Task breakdown

1. Auth/session behaviour offline; subscription entitlements + revoked access.
2. Multi-account device isolation; cache purge on logout.
3. XSS/HTML sanitization (`dompurify` already present), CSP, CORS, private images.
4. Offline telemetry (Sentry) without sensitive payloads.
5. PWA update migrations; stale-client recovery.
6. Performance + accessibility baselines.
7. Build an **offline scenario matrix** and rollback plan.

## 5. Files to change

| File | Action |
|---|---|
| `src/utils/*` (sanitization paths) | Verify/Harden |
| CSP/headers config (Cloudflare) | Verify/Harden |
| `playwright.config.ts` + mobile projects | Modify |
| `docs/` offline scenario matrix | New |
| Various (fixes from findings) | Modify |

## 6. Tests

- Logout/account switching, subscription expiry, cache invalidation.
- XSS, auth refresh, outbox retries, SW updates, storage quota.
- Offline/online transitions; accessibility; desktop regression.

## 7. Acceptance criteria

- No cross-account leakage; no bypass of Rails authorization.
- Offline write rejection surfaced; no desktop regressions.
- Performance + accessibility baselines agreed.

## 8. Risks, compatibility, rollback

- **Risk:** hardening changes alter behaviour. **Mitigation:** fix issues without
  changing core domain behaviour; document each.
- **Rollback:** documented production rollback procedure (feature flags + SW
  cleanup release).

## 9. AI coding prompt (from the master plan)

> Perform a focused security/reliability audit of Wine Words PWA and offline
> functionality. Test logout/account switching, subscription expiry, cache
> invalidation, XSS, auth refresh, outbox retries, SW updates, storage quota,
> offline/online transitions, accessibility and desktop regression. Fix issues
> without changing core domain behavior. Provide a production release checklist,
> monitoring signals and rollback procedure.

## 10. Gate checklist

### Implementation result (2026-11-03)

- Account-scoped purge/isolation, authorization-safe cache fallback, retry/backoff,
  conflict retention, typecheck, lint and production build checks pass.
- `npm audit --omit=dev` reports **62 production-tree advisories: 8 low, 20
  moderate, 31 high and 3 critical**. Resolve through a dedicated tested dependency
  upgrade; do not use an unreviewed `npm audit fix --force` before release.

- ⬜ No cross-account leakage
- ⬜ Offline write rejection surfaced
- ⬜ Offline scenario matrix + rollback documented
- ⬜ Accessibility/performance baselines agreed
