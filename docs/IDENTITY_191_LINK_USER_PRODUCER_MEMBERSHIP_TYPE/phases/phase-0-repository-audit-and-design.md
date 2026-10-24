# Phase 0 — Repository Audit and Design Alignment

## Overview

Issue #191 requires typed producer memberships (`owner`, `manager`, `contributor`) without introducing any follower functionality. This is an upgrade and authorization‑hardening task, not a new feature.

## Existing Issue #187 Implementation

- `producer_memberships` join table exists with `user_id`, `producer_id`, `created_by_id`, timestamps.
- Unique composite index `(user_id, producer_id)`.
- No `membership_type` column.
- `ProducerMembership`, `User`, and `Producer` associations are already defined.
- Admin/Editor membership listing, creation, and deletion are implemented.
- `/users` and `/users/:id` endpoints exist.
- `/account` → **My Producers** list is implemented.
- Producer‑linked user information appears on Producer detail pages.
- Existing authorization checks intend to allow linked users to edit producers, but the fallback was inert: `ensure_wine_manager!` ran before `set_producer`, so `@producer` was always nil and only `wine_manager?` (Admin/Editor/Reviewer) could edit or delete. Phase 2 fixes the ordering and makes the rule membership-aware.
- No `Follow` implementation exists or is planned.

## Migration State

- The migration `20261021234637_create_producer_memberships.rb` has already been applied in development, staging, and production.
- The current schema contains no `membership_type` column.
- Local development database contains **0** producer memberships.

## Schema and Data Audit

| Item | Value |
|------|-------|
| Table name | `producer_memberships` |
| Columns | `id`, `user_id`, `producer_id`, `created_by_id`, `created_at`, `updated_at` |
| Indexes | Unique `(user_id, producer_id)` |
| Constraints | None beyond foreign keys and timestamps |
| Existing rows | 0 |
| Null/untyped rows | N/A (none) |

## Authorization Policy Review

- **Global Admin**: can view/edit all users, manage global roles, manage subscriptions, manage producer memberships for any user.
- **Global Editor**: can view/edit all users (read‑only on global role/subscription), manage producer memberships for any user (subject to existing restrictions), cannot modify global roles or subscriptions.
- **Owner / Manager**: can edit only their own associated Producer profile (update, logo upload/remove). No membership administration.
- **Contributor**: read‑only for Producer details; cannot edit any Producer.
- **Reviewer (wine_manager?)**: currently has global producer‑management permissions via `wine_manager?`; these are outside issue #191 and will be preserved.
- **Subscription**: Admin‑only.
- **Producer creation**: Admin‑only (global catalogue policy).

## API Contract Review

- Existing endpoints:
  - `GET /api/v1/producers`
  - `GET /api/v1/users/:user_id/producer_memberships` (list)
  - `POST /api/v1/users/:user_id/producer_memberships` (create)
  - `PATCH /api/v1/users/:user_id/producer_memberships/:id` (update)
  - `DELETE /api/v1/users/:user_id/producer_memberships/:id` (delete)
  - `GET /api/v1/account/producers` (own account list)
- Payloads:
  - Create: `{ "producer_membership": { "producer_id": 42, "membership_type": "manager" } }`
  - Update: `{ "producer_membership": { "membership_type": "owner" } }`
- Authentication: derived from current user; no client‑supplied `created_by_id`.

## Frontend Components Review

- **AccountSettings.tsx**: privacy opt‑out, sign‑in methods, my producers list. No membership‑type UI.
- **ProducerDetail.tsx**: loads linked user info; no membership type badge.
- **ProducerForm.tsx**: fields for producer details; no membership handling.
- **UserRoles.tsx**: role badges, subscription selector; no membership handling.
- **My Producers** section in AccountSettings: list of linked producers, no edit affordance based on membership type.
- Reusable components: `WineTable`, `RegionSearch`, `GrapeSearch` are unchanged.

## Test Coverage and Gaps

- Unit tests for `ProducerMembership` model exist (basic associations).
- Request specs for producer CRUD exist but do not cover membership type or authorization.
- No tests for:
  - `owner`, `manager`, `contributor` type enforcement.
  - Owner/Manager edit capability on their own Producer.
  - Contributor denial.
  - Cross‑Producer access denial.
  - Membership type mutation via API.
- Existing frontend tests (`AccountSettings.test.tsx`, `ProducerDetail.test.tsx`, `ProducerForm.test.tsx`) cover UI rendering but not membership‑type logic.

## Decisions & Deviations from Original Plan

1. **Do not rewrite the existing migration** – it is already applied; a forward migration will be added.
2. **Legacy untyped rows** – will be resolved only after an explicit inventory step; the migration will fail safely if untyped rows exist.
3. **Global roles and subscriptions** – remain Admin‑only; Editors keep read‑only access, no new privilege‑management powers.
4. **Owner/Manager edit capability** – identical for both roles in this release; no separate privilege distinction.
5. **Reviewer permissions** – preserved; they keep existing global producer‑management rights, which are unrelated to issue #191.
6. **Linked‑member delete permission** – restricted so that only global Admin/Editor can delete a Producer. This also removes deletion from Reviewers (they keep create/edit), because issue #191 names Admin/Editor as the deletion boundary.
7. **Contributor** – remains read‑only for Producer details; no edit affordance.
8. **Server‑derived edit capability** – the API will expose a `can_edit` flag; UI will respect it, but backend authorization remains authoritative.
9. **`/account/producers` endpoint** – will be enhanced to include membership type and edit capability, not replaced by a new endpoint.
10. **No follower logic** – strictly out of scope; the plan explicitly excludes `follower` and `viewer` values.

## Next Steps

All phases are implemented. See the status table in the master plan and:

- [Phase 1 — Schema and model](phase-1-schema-and-model.md)
- [Phase 2 — Producer authorization](phase-2-producer-authorization.md)
- [Phase 3 — Membership API](phase-3-membership-api.md)
- [Phase 4 — `/account/producers`](phase-4-my-producers-payload.md)
- [Phase 5 — Frontend UserDetail](phase-5-frontend-user-detail.md)
- [Phase 6 — Frontend account/producer detail](phase-6-frontend-account-and-producer-detail.md)
- [Phase 7 — Tests and validation](phase-7-tests-and-validation.md)
- [Phase 8 — Rollout and risks](phase-8-rollout-and-risks.md)