# Phase 7 — Testing Matrix & Results

**Status:** ✅ Executed 2026-10-26 (all numbers below are real runs)

## New tests

| File | Examples | Result |
|---|---|---|
| `spec/services/account_deletion_service_spec.rb` | 9 | ✅ 0 failures |
| `spec/requests/api/v1/users_deletion_spec.rb` | 10 | ✅ 0 failures |

Coverage highlights per the plan's matrix:

* **Lifecycle:** soft delete stamps `deleted_at`; idempotent repeats fail; reactivate
  clears the stamp; job enqueued on soft delete.
* **Policy:** billing dependency and last-admin produce `blocking_reasons`; flag-off
  refuses with `hard_delete_disabled`.
* **Request/auth:** admin vs non-admin (403), missing user (404), flag off (403),
  blocked (409) with user preserved, hard delete removes user + account, deleted
  account gets `403 account_deleted` on `GET /me`.

## Regression evidence

| Suite | With changes | Pristine tree (`git stash`) | Verdict |
|---|---|---|---|
| Rails full suite | 1560 examples, 45 → **44 failures** (second run) | 1544 examples, 44 failures | **Identical failure sets** (`diff` clean) — 16 new examples all pass, zero regressions |
| `user_spec`, `billing_spec`, users request specs | 42 examples, 1 failure | same failure on pristine | pre-existing seed-data issue (`billing_spec.rb:44`, expects 700 got 7000) |
| Frontend `tsc --noEmit` | clean | — | ✅ |
| Frontend `vitest` full | 408 passed, 4 failed | same 4 fail on pristine | pre-existing (`ProducerDetail`, `Reviews`, `ApiHealth`) |

## Not yet covered (recommended follow-ups)

* Concurrency spec simulating a blocking write between policy check and transaction
  (exercise `BlockedError` → `409` path under race).
* `DeleteUserJob#perform` unit spec for each skip branch (reactivated / flag off /
  missing user).
* Audit-log content assertions (actor recorded, description string).
* Staging dry-run with synthetic accounts per dependency category (Phase 8 rollout
  step 4).