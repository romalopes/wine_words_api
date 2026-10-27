# Phase 3 — Lifecycle Service, Transaction Safety & Background Job

**Status:** ✅ Complete

## Files

| File | Role |
|---|---|
| `app/services/account_deletion_service.rb` | soft delete / reactivate / hard delete / schedule |
| `app/services/deletion_policy.rb` | blocking-dependency evaluation (Phase 2) |
| `app/jobs/delete_user_job.rb` | 30-day grace-period hard delete |
| `app/models/user.rb` | `soft_delete!` / `reactivate!` model-level primitives |

## `AccountDeletionService` API

All entry points return a `Result` struct (`success`, `user`, `error`,
`blocking_reasons`):

* **`.soft_delete(user, actor:)`** — row-locks the user, stamps `deleted_at`, revokes
  the presented JWT, writes an audit entry, then **after commit** enqueues
  `DeleteUserJob` with `wait: 30.days`. Idempotent (`already_deleted` on repeat).
* **`.reactivate(user, actor:)`** — clears `deleted_at`; no implicit restoration of
  obsolete memberships/credentials. Idempotent (`not_deleted`).
* **`.hard_delete(user, actor:)`** — refused unless `AppSetting.hard_delete_enabled?`
  (disabled by default). Re-checks the policy, then inside **one transaction**:
  row-lock → re-evaluate policy (TOCTOU protection) → destroy disposable dependents
  (`likes`, `follows`, `notifications`, `notification_preference`, `user_roles`,
  `user_identities`, `user_subscriptions`, `billing_customers` is never reached while
  blocked) → destroy `account` → destroy `user`. A `BlockedError` raised inside the
  transaction rolls everything back and returns `blocked` with reasons — **no partial
  deletion**.
* **`.schedule_hard_delete(user)`** — manual enqueue used by the soft-delete flow.

## Safety properties (plan §6)

* **Time-of-check / time-of-use races:** `lock!` + policy re-evaluation inside the
  transaction; concurrent blocking writes surface as `BlockedError` → safe refusal.
* **No broad cascades:** reviews/articles/comments/producer memberships/financial
  records are never destroyed here — they are *blocking*.
* **Audit:** `LogService.log` entries (`soft_delete`, `reactivate`, `hard_delete`,
  `scheduled_hard_delete`) with actor and user/account objects; logging failures never
  break the operation (LogService contract).
* **Idempotency:** repeated soft-delete → `already_deleted`; job re-run after
  reactivation → no-op; job re-run after hard delete → no-op (user gone).
* **External cleanup:** DB transactions cannot include Stripe/storage — the job + the
  BLOCKING billing rule guarantee external obligations are resolved before deletion;
  non-DB erasure (backups, provider copies) is explicitly not claimed.

## `DeleteUserJob`

Skips unless the user still exists, is still soft-deleted, **and**
`AppSetting.hard_delete_enabled?` is true at execution time — so toggling the flag off
pauses the pipeline without data loss.

## Test evidence

`spec/services/account_deletion_service_spec.rb` (9 examples) covers soft delete,
reactivation, flag-disabled refusal, successful hard delete (user + account gone),
billing-blocked refusal with reasons, last-admin block, and `DeleteUserJob` enqueuing.