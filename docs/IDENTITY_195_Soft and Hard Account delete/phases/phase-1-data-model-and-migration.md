# Phase 1 — Data Model & Migration

**Status:** ✅ Complete

## What was done

| Change | File |
|---|---|
| Additive migration: `users.deleted_at :datetime` (nullable) + index | `db/migrate/20261026000001_add_deleted_at_to_users.rb` |
| Schema regenerated with the new column + `index_users_on_deleted_at` | `db/schema.rb` |
| Lifecycle scopes: `User.not_deleted`, `User.deleted` | `app/models/user.rb` |
| `User#deleted?`, `User#soft_delete!`, `User#reactivate!` (row-locked, transactional, idempotent) | `app/models/user.rb` |
| Current-token revocation via exact-jti `JwtDenylist` entry | `app/models/user.rb#revoke_sessions!` |
| Server-side rejection of deleted accounts on every request | `app/controllers/application_controller.rb#reject_deleted_user!` |

## Decisions

* **`status` column not added.** The plan permits an enum/string only when no equivalent
  mechanism exists; `deleted_at` fully expresses soft deletion today. Adding `active /
  suspended / deactivated` states is deferred until a product need exists (avoids
  speculative fields, per plan §4).
* **No `default_scope`.** Excluded users are filtered with explicit scopes / the request
  guard, per plan §4.
* **`anonymized_at` not added** — anonymisation is a later, separate release.
* **Email uniqueness:** soft-deleted users keep occupying their email (unique index
  unchanged). Re-registration is blocked until hard delete or an explicit email release.
* **Session revocation:** the denylist can only revoke the exact `jti` presented at
  deletion time; comprehensive enforcement is `ApplicationController#reject_deleted_user!`
  (403 `account_deleted` on any authenticated request), so stale tokens from other
  devices are useless.

## Migration safety

Additive-only (`add_column` + `add_index`); reversible via `change`; no data backfill
needed (`deleted_at` starts NULL = active).

## Verification

`bin/rails db:migrate` ran clean; `spec/models/user_spec.rb` and user request specs
green (see Phase 7 report).