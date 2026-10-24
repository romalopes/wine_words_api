# Phase 5 — Frontend: User Detail Membership Administration

**Issue:** #191
**Status:** Complete
**Scope:** `wine_words` (React)

## Goal

Let Admin/Editor choose a membership type when linking a producer, see the type on every row, and change it later — without disturbing unsaved global-role edits or the subscription panel.

## Files changed

| File | Change |
|---|---|
| `src/types/producer.ts` | `ProducerMembershipType` union; `Producer.can_edit`; `ProducerSummary.membership_id` / `membership_type` / `can_edit`. |
| `src/types/user.ts` | `ProducerMembership.membership_type` (required), `can_edit?`, `updated_at?`. |
| `src/types/api.ts` | `usersApi.producerMemberships.create` takes a type; new `update`. |
| `src/constants/roles.ts` | `PRODUCER_MEMBERSHIP_TYPES`, `PRODUCER_MEMBERSHIP_LABELS`, `producerMembershipLabel`, `canEditProducerMembership`, `canDeleteProducers`. |
| `src/services/accountApi.ts` | Nested `producer_membership` bodies for POST/PATCH. |
| `src/components/UserDetail.tsx` | Type picker in the link form, badge + per-row type select with change handler. |
| `src/index.css` | `.membership-badge` variants + `.membership-type-field`. |

## UserDetail behaviour

1. A **Membership type** select sits beside the producer search box. It defaults to `Manager` — an accidental manager grant is safer than an accidental owner grant, and the admin still has to choose for the non-default cases.
2. Linking posts `{ producer_membership: { producer_id, membership_type } }` and appends the returned membership (which already carries `membership_type`).
3. Each linked producer shows a colour-coded badge (`Owner` / `Manager` / `Contributor`) plus a per-row **Type** select.
4. Changing the select PATCHes only `membership_type` and patches local state with the server response — global roles and subscription state are untouched, so unsaved role checkbox changes survive a membership edit.
5. Unlink is unchanged (confirm dialog, `DELETE`).

Errors keep the existing convention (`alert` + `console.error`), which matches the rest of this component; the component is already dense and introducing a second error channel here would be inconsistent.

## Constants (single source of truth)

```ts
export const PRODUCER_MEMBERSHIP_TYPES = ["owner", "manager", "contributor"] as const
export const PRODUCER_MEMBERSHIP_LABELS = { owner: "Owner", manager: "Manager", contributor: "Contributor" }
```

`follower` and `viewer` are not present anywhere in the frontend, by design. `canEditProducerMembership` mirrors the backend rule but is only used for UI defaults — the API's `can_edit` wins.

## Pre-existing bug fixed in passing

`UserDetail.tsx` rendered `membership.producer.country?.name`, but the API returns `country` as a **string**. The country line therefore always fell back to "No country" and `tsc` flagged it. It now renders `membership.producer.country || "No country"`.

## Verification

- `npm run typecheck` → clean (also removed three pre-existing unused-import/variable errors in `UserDetail.tsx` and `GrapeDetail.tsx` so the project now type-checks).
- `npm run lint` → 0 errors (6 pre-existing warnings elsewhere).
- Manual contract review against the Phase 3 response shape.

## Notes / deviations

- The link form still uses the existing inline search + results list rather than a new reusable `ProducerSearchSelect` component. The existing control already debounces, excludes linked producers and handles empty results; extracting it would touch other screens and was not required to satisfy the issue. Recorded as a deliberate deviation in Phase 8.
- No optimistic UI: the row updates from the server response, so a simultaneous change by another admin is never silently overwritten.
