# IDENTITY_195 — Account Lifecycle & Deletion: Implementation Report

**Date:** 2026-10-26 · **Scope:** Phases 0–5 of `Wine_Words_Account_Lifecycle_Deletion_Plan.md`, plus test matrix (7) and rollout docs (8).

## Executive summary

Admin-only **soft delete** and **hard delete** are implemented end-to-end, with hard
delete gated behind an `AppSetting` feature flag that is **disabled by default**.
Soft delete is fully reversible and schedules a 30-day grace-period job; hard delete is
fail-closed against a structured dependency policy and refuses (`409`) any account with
blocking dependencies (published reviews/articles, comments, producer memberships,
billing/subscription history, sole-admin).

## Delivered

| Phase | Deliverable | Files |
|---|---|---|
| 0 | Dependency inventory (BLOCKING / DISPOSABLE / RETAIN-SEPARATELY / REVIEW) | `dependency_inventory.md`, `phases/phase-0-*.md` |
| 1 | `users.deleted_at` migration + scopes + lifecycle primitives + server-side deletion guard | `db/migrate/20261026000001_*`, `app/models/user.rb`, `app/controllers/application_controller.rb`, `db/schema.rb` |
| 2 | Structured, fail-closed `DeletionPolicy` | `app/services/deletion_policy.rb` |
| 3 | Transaction-safe `AccountDeletionService` + `DeleteUserJob` + feature flag | `app/services/account_deletion_service.rb`, `app/jobs/delete_user_job.rb`, `app/models/app_setting.rb` |
| 4 | Admin endpoints: soft delete / hard delete / reactivate | `config/routes.rb`, `app/controllers/api/v1/users_controller.rb` |
| 5 | Admin UI: lifecycle section + confirmation modal | `wine_words/src/components/UserDetail.tsx`, `src/services/accountApi.ts`, `src/types/{api,user}.ts` |
| 7 | 19 new examples; regression-proven | `spec/services/account_deletion_service_spec.rb`, `spec/requests/api/v1/users_deletion_spec.rb`, `phases/phase-7-testing.md` |
| 8 | Rollout checklist + runbook | `phases/phase-8-rollout-and-runbook.md` |

## Key decisions

1. **`User` is the single source of lifecycle truth** (`deleted_at`); `Account` stays a
   profile child and is destroyed only by hard delete.
2. **No `status` / `anonymized_at` columns yet** — speculative fields avoided; the
   `deleted_at` timestamp fully expresses soft deletion today.
3. **No `default_scope`** — explicit `User.not_deleted` / `User.deleted` scopes plus the
   `reject_deleted_user!` request guard.
4. **Session enforcement is server-side, not just denylist.** devise-jwt's denylist
   matches exact `jti`, so only the presented token can be revoked at deletion time;
   `ApplicationController#reject_deleted_user!` (403 `account_deleted`) is the
   authoritative gate for stale tokens on other devices.
5. **Email re-registration after soft delete is blocked** (unique index unchanged) —
   deliberate, not silently rewritten; product owner can revisit.
6. **Last-admin protection** counts admins *excluding the target*, so one admin can
   remove a colleague while another remains.
7. **Blocked hard deletes are atomic refusals** — policy is re-evaluated inside the
   row-locked transaction; `BlockedError` rolls back everything and surfaces `409`.

## Test evidence (executed)

* New specs: **19 examples, 0 failures** (9 service + 10 request).
* Rails full suite: failure set **identical** to the pristine tree (`git stash` A/B,
  `diff` clean) — zero regressions. Pre-existing failure `billing_spec.rb:44` is
  seed-data dependent and unrelated.
* Frontend: `tsc --noEmit` clean; `UserDetail.test.tsx` passing; the 4 failing frontend
  tests exist on the pristine tree (`ProducerDetail`, `Reviews`, `ApiHealth`).
* RuboCop: new files clean apart from the codebase-wide `Layout/SpaceInsideArrayLiteralBrackets` style that pre-exists in untouched lines.

## Residual risks / follow-ups

* **Race-condition spec** for the in-transaction `BlockedError` path (logic implemented
  and exercised indirectly; dedicated concurrency test recommended).
* **`DeleteUserJob` unit spec** for its three skip branches.
* **Serializer gap:** `users#show` does not yet emit `deleted_at`; the frontend treats
  it as optional and falls back to the active state. Add `deleted_at: user.deleted_at`
  to `user_detail_json` in the next serializer pass.
* **Batch sweep job** (periodic re-enqueue of overdue soft-deleted users) is manual
  today (runbook command); a recurring Solid Queue entry can be added at rollout.
* **Anonymisation / user-initiated deletion** remain the later, separate release
  (plan Phase 6 / §13 "Later").