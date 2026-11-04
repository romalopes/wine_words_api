# Phase 3 — Mobile Finder, Quiz and More

**Status:** ⬜ Not started (planned)
**Date:** 2026-11-03
**Repositories:** [wine_words (frontend)](https://github.com/romalopes/wine_words_frontend) · [wine_words_api](https://github.com/romalopes/wine_words_api)
**Gate:** A — Responsive mobile experience
**Master plan:** [`../Wine_Words_Mobile_PWA_Implementation_Plan.md`](../Wine_Words_Mobile_PWA_Implementation_Plan.md) · Issue [#201](https://github.com/romalopes/wine_words_api/issues/201)

---

## 1. Objective and scope

Adapt the Finder (`/finder` → `Home.tsx`) and Quiz (`/quiz` → `Quiz.tsx`) pages
for mobile and complete the **More** menu grouping. Preserve existing business
logic and APIs.

## 2. Prerequisites

- Phase 1 (mobile shell + More menu scaffold).

## 3. Tools to install

**None.**

## 4. Task breakdown

1. **Finder:** mobile filter drawer / bottom sheet; usable result cards; keep
   existing query params and pagination.
2. **Quiz:** responsive question controls, large answer targets, persistent
   progress indicator; keep scoring logic in `Quiz.tsx` unchanged.
3. **More menu:** populate from existing routes + role checks; verify each link
   resolves in production before enabling.
4. **States:** loading/empty/error handling at mobile widths.

## 5. Files to change

| File | Action |
|---|---|
| `src/components/Home.tsx` (Finder) | Modify (mobile filters/results) |
| `src/components/Quiz.tsx` | Modify (mobile controls/progress) |
| `src/components/MoreMenu.tsx` | Modify (populate routes) |
| `src/index.css` | Modify |
| Tests beside changed components | Modify/New |

## 6. Tests

- Viewport tests at 320–430px; keyboard accessibility for filters and answers.
- Route-resolution test for every More entry (role-gated).

## 7. Acceptance criteria

- Finder and Quiz usable at 320–430px, keyboard accessible.
- Existing business logic preserved.
- No offline caching in this phase.

## 8. Risks, compatibility, rollback

- **Risk:** Finder filter state lost on narrow screens. **Mitigation:** keep state
  in URL search params.
- **Rollback:** revert responsive changes.

## 9. AI coding prompt (from the master plan)

> Audit current `/finder` and `/quiz` pages and APIs. Adapt existing UI for
> mobile: touch-friendly Finder filters, readable results, large Quiz answer
> targets and persistent navigation where appropriate. Build More menu from
> existing routes and role checks. Do not fork business logic or add offline
> caching in this phase. Add viewport and accessibility tests.

## 10. Gate checklist

- ⬜ Finder/Quiz usable on mobile
- ⬜ More menu links verified and role-gated
- ⬜ Gate A (Phases 0–3) ready for review
