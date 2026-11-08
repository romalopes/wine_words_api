# Phase 2 — Mobile Reviews, Articles, Comments and Likes

**Status:** ⬜ Not started (planned)
**Date:** 2026-11-03
**Repositories:** [wine_words (frontend)](https://github.com/romalopes/wine_words_frontend) · [wine_words_api](https://github.com/romalopes/wine_words_api)
**Gate:** A — Responsive mobile experience
**Master plan:** [`../Wine_Words_Mobile_PWA_Implementation_Plan.md`](../Wine_Words_Mobile_PWA_Implementation_Plan.md) · Issue [#201](https://github.com/romalopes/wine_words_api/issues/201)

---

## 1. Objective and scope

Make browsing, reading, commenting and liking usable at phone widths while
preserving desktop behaviour, routes, permissions and subscription gates. Reuse
the existing API, hooks and components — adapt presentation, do not fork logic.

## 2. Prerequisites

- Phase 1 (mobile shell) merged.

## 3. Tools to install

**None.** Reuse existing components, `hooks/useComments.ts`, `hooks/useLike.ts`.

## 4. Task breakdown

1. **List cards** (`ReviewCard.tsx`, `ArticleCard.tsx`): responsive image ratios
   (`AdaptiveImage.tsx`), typographic scale, touch targets.
2. **Detail pages** (`ReviewDetail.tsx`, `ArticleDetail.tsx`): reading typography,
   sticky actions where useful, safe-area spacing.
3. **Filters/search/pagination**: responsive `ReviewsSearch`/`ArticlesSearch`
   controls and `Pagination.tsx` at narrow widths.
4. **Comments** (`src/components/comments/*`): mobile-friendly thread, deep-linkable
   comment anchors (`CommentLink.tsx`), accessible reply/edit/delete controls.
5. **Likes** (`LikeButton.tsx`): ensure touch target + state readability.
6. **Subscription paywalls**: keep existing gating untouched; verify mobile
   presentation of the paywall.

## 5. Files to change

| File | Action |
|---|---|
| `src/components/Reviews.tsx`, `Articles.tsx` | Modify (responsive list layout) |
| `src/components/ReviewCard.tsx`, `ArticleCard.tsx` | Modify |
| `src/components/ReviewDetail.tsx`, `ArticleDetail.tsx` | Modify |
| `src/components/comments/CommentList.tsx`, `CommentItem.tsx`, `CommentForm.tsx` | Modify |
| `src/components/LikeButton.tsx` | Modify (touch target) |
| `src/index.css` | Modify (responsive content styles) |
| `*.test.tsx` beside changed components | Modify/New |

## 6. Tests

- Unit: components render at mobile widths; comment anchors resolve.
- Integration: logged-out and restricted users see correct gating.
- Accessibility: touch targets, focus order.

## 7. Acceptance criteria

- Browsing/reading/commenting works at phone widths; desktop unchanged.
- Server authorization still enforced (no client-side trust).
- Tests cover logged-out and restricted users.

## 8. Risks, compatibility, rollback

- **Risk:** layout regressions on desktop. **Mitigation:** media-query scoping +
  visual regression snapshots.
- **Rollback:** revert the responsive CSS changes (no data/API change).

## 9. AI coding prompt (from the master plan)

> Inspect current Reviews, Articles, comments/replies and likes components and
> their API hooks. Make them mobile-friendly with minimal component changes and
> responsive styles, while preserving desktop behavior, routes, permissions and
> subscription gates. Include comment deep-link targets, accessible touch controls
> and regression tests. Do not implement offline writes yet.

## 10. Gate checklist

- ⬜ Reviews/Articles readable at 320–430px
- ⬜ Comments/replies/likes usable and accessible
- ⬜ Desktop + paywall regressions clean
