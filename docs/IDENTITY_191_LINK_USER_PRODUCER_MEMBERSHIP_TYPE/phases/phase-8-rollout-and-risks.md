# Phase 8 — Rollout, Risks and Follow-ups

**Issue:** #191
**Status:** Complete (code), deployment actions pending
**Scope:** both repositories

## Deployment order

1. **Back up** `producer_memberships` (or take a database snapshot).
2. **Inventory** the target environment:
   ```sql
   SELECT COUNT(*) AS total,
          COUNT(*) FILTER (WHERE membership_type IS NULL) AS untyped
     FROM producer_memberships;
   ```
   (On environments where the column does not exist yet, run the count *before* migrating and treat every row as untyped.)
3. **Migrate before deploying the new app code.** The new code requires the column; the old code keeps working after the migration because the column has no default and old writers do not insert rows… which means old writers *will* fail if they create a membership during the deploy window. Keep the window short, or deploy with the API in maintenance/read-only for membership writes.
   - If `untyped > 0`, re-run with the approved mapping:
     `PRODUCER_MEMBERSHIP_LEGACY_TYPE=manager bin/rails db:migrate` (or `contributor` if the data owner prefers read-only).
4. **Deploy the React app.** It tolerates an API without `membership_type` (`can_edit` simply stays undefined → no Edit affordance), so the frontend can also go first if the API deploy slips.
5. **Smoke test** as Admin: link a producer as `owner`, reload `/users/:id` (badge + select), open `/account` (badge + Edit), sign in as that user (edit allowed), change them to `contributor` (edit denied, `403` on direct PATCH).

## Rollback

- `bin/rails db:rollback STEP=1` removes the check constraint and the column. **This loses the membership types**; re-migrating then requires the legacy-mapping env var again (all rows are untyped after the rollback).
- Because of that, roll back the application code first if the problem is behavioural; only roll back the migration if the schema itself is wrong.
- Dropping the column does not reintroduce invalid values, satisfying the plan's "a downgrade must not reintroduce invalid values" requirement.

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Staging/production hold untyped rows | Migration stops | Explicit, actionable error + whitelisted `PRODUCER_MEMBERSHIP_LEGACY_TYPE` mapping; run the inventory first |
| Deploy window with old app + new schema | Old code creating a membership fails `NOT NULL` | Short window, or pause membership writes during deploy |
| Reviewer delete removal | Reviewers lose a capability they had | Deliberate per issue #191; documented in Phase 2. Restore by changing `ensure_catalogue_manager!` to `ensure_wine_manager!` for `destroy` if product disagrees |
| Owner/manager are indistinguishable | No "owner-only" actions | Accepted for this release (Phase 0 decision 4) |
| No last-owner protection | A producer can end up with no owner | Producers are not required to have an owner; revisit if the business rule changes |
| Impersonation | Admin acting as a contributor could look read-only | Server authorization uses `real_current_user`; UI shows the effective user's `can_edit`, which is conservative |
| Hand-rolled membership checks in controllers | Divergence from future policy layer | All rules live in `ProducerMembership::EDITABLE_TYPES` + `ProducersController` helpers; extract to a policy object if a fourth consumer appears |

## Deliberate deviations from the v3 plan

1. **No `ProducerSearchSelect` extraction.** The existing debounced search in `UserDetail` was reused; extracting a shared component would touch unrelated screens.
2. **Reviewers keep create/edit but lose delete.** The plan's matrix did not mention Reviewer deletion explicitly; issue #191 restricts deletion to catalogue managers.
3. **Legacy mapping is opt-in via env var** instead of a manual `UPDATE` script, because a failing migration rolls back the column and leaves the operator unable to run that `UPDATE`.
4. **`/account/producers` enhanced, not replaced** (Phase 0 decision 9).
5. **No follower/viewer anywhere** — model, check constraint, API, TypeScript union and UI all exclude them; no Follow table or endpoints exist.

## Accepted follow-ups (not in this issue)

- Reusable `ProducerSearchSelect` component.
- Component test for `UserDetail`.
- Extract producer authorization into a policy object shared by controllers.
- Retire the legacy flat create payload once no client uses it.
- Optional optimistic locking (`lock_version`) on `producer_memberships` if concurrent admin edits become a real problem.
- Show the Linked Users list to producer owners/managers (requires widening `GET /producers/:id/memberships`).

## Acceptance checklist (mapped to Issue #191)

- [x] `membership_type` is required and limited to owner/manager/contributor (model + DB constraint).
- [x] Admin/Editor can assign, change and remove a membership type.
- [x] Owner and Manager can edit their own producer; Contributor cannot.
- [x] Unlinked users cannot edit a producer through direct API requests.
- [x] Producer deletion is restricted to Admin/Editor.
- [x] `/account` shows only the signed-in user's producers, with type and edit capability.
- [x] Invalid membership types fail with a clear 422; duplicates return 409; unknown/deleted producers 404.
- [x] No `follower`/`viewer` value, Follow model, Follow button or follow endpoint was added.
- [x] Existing global roles, subscriptions, producer forms and unrelated functionality are intact (verified against the pre-existing test baseline).
