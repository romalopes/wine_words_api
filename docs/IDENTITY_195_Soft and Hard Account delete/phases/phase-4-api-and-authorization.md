# Phase 4 — API & Authorization

**Status:** ✅ Complete

## Routes (`config/routes.rb`)

```
DELETE /api/v1/users/:id/soft_delete   → users#soft_delete   (admin)
DELETE /api/v1/users/:id/hard_delete   → users#hard_delete   (admin + feature flag)
POST   /api/v1/users/:id/reactivate    → users#reactivate    (admin)
```

## Authorization

* Every action starts with `real_current_user&.admin?` — impersonating a non-admin
  cannot grant admin powers (same pattern as `assign_roles` / `assign_subscription`).
* Hard delete additionally requires `AppSetting.hard_delete_enabled?`, which is
  **false by default**; disabled flag → `403` with `hard_delete_disabled`.

## Responses

| Case | Status | Body |
|---|---|---|
| Soft delete ok | `200` | `{ status: "soft_deleted", user_id }` |
| Soft delete repeat/failure | `422` | `{ error }` |
| Hard delete ok | `200` | `{ status: "hard_deleted", user_id }` |
| Hard delete blocked by dependencies | **`409`** | `{ error: "blocked", blocking_reasons: [...] }` |
| Hard delete of already-deleted user | `410` | `{ error: "already_deleted" }` |
| Hard delete flag off | `403` | `{ error: "hard_delete_disabled" }` |
| Reactivate ok | `200` | `{ status: "reactivated", user_id }` |
| Any action by non-admin | `403` | `head(:forbidden)` |
| Unknown user | `404` | (Rails `RecordNotFound`) |

## Audit logging

`@target_user` is set before the service call so the existing `audit_actions` /
`log_objects` machinery records the admin action alongside the service's own
`LogService` entries.

## Server-side deletion enforcement

`ApplicationController#reject_deleted_user!` (runs after `authenticate_user!` on every
API request) returns `403 { code: "account_deleted" }` for any soft-deleted user and
revokes the presented JWT — the authoritative gate for "deleted users cannot use
tokens".

## Test evidence

`spec/requests/api/v1/users_deletion_spec.rb` (10 examples): admin success paths,
non-admin 403s, missing user 404, flag-off 403, blocked 409 with user preserved, and
the deleted-account access rejection.