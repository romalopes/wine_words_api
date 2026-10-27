# Phase 8 — Rollout Checklist & Operational Runbook

**Status:** 📋 Prepared (no production commands executed)

## Rollout order

1. **Backup** production DB; confirm restore procedure works on the backup copy.
2. **Deploy additive migration** (`20261026000001_add_deleted_at_to_users.rb`) first;
   verify `users.deleted_at` + `index_users_on_deleted_at` exist (`\d users` in psql).
3. **Deploy services + endpoints** with hard deletion **disabled** (default — no
   `app_settings` row needed; `AppSetting.hard_delete_enabled?` defaults to `false`).
4. **Deploy frontend**; validate in staging with synthetic accounts covering every
   dependency category: disposable-only (likes/follows/notifications), reviews,
   articles, comments, producer membership, subscription changes, billing customer,
   sole-admin.
5. Verify authorization (non-admin 403), audit entries in the Logs page, soft delete →
   reactivate round-trip, and that deleted accounts get `403 account_deleted`.
6. **Enable hard delete for a limited admin cohort**: `AppSetting.set!("hard_delete_enabled",
   "true")` (or the Configuration page custom setting). Review logs and blocked
   `409` requests.
7. Enable generally only after sign-off.

## Runbook

### Restore a soft-deleted account
```
# 1. In the admin UI: Users → user → Account Lifecycle → "Reactivate user"
# 2. Or via API:
curl -X POST -H "Authorization: Bearer <admin-token>" \
  https://<host>/api/v1/users/<id>/reactivate
```
Restoration clears `deleted_at` only; it does not resurrect destroyed rows.

### Pause the hard-delete pipeline
```
AppSetting.set!("hard_delete_enabled", "false")
```
Already-enqueued `DeleteUserJob`s become no-ops (they re-check the flag at execution).

### Check whether an account is eligible for hard delete
Inspect the `blocking_reasons` returned by a `409` from
`DELETE /api/v1/users/:id/hard_delete`, or run in console:
```ruby
policy = DeletionPolicy.new(User.find(id))
policy.hard_delete_allowed?
policy.blocking_reasons   # => [{code:, count:, message:}, ...]
policy.disposable_counts
```

### Run the grace-period job manually (batch sweep)
```ruby
User.deleted.find_each do |user|
  next unless user.deleted_at < 30.days.ago
  DeleteUserJob.perform_later(user.id)
end
```

### If an accidental hard delete occurs
The DB row is unrecoverable without a **point-in-time restore** (soft delete is the
safety net; hard delete is only enabled after sign-off). Restoring from backup must
also re-check Stripe consistency for the affected billing records.

### Known non-erasure surface
Hard delete erases DB rows only; copies may persist in email provider, disk logs,
object-storage backups and Stripe. Communicate this in data-subject responses.

## Monitoring

* Watch `LogService` audit entries with actions `soft_delete`, `reactivate`,
  `hard_delete`, `scheduled_hard_delete`.
* Alert on `DeleteUserJob` failures (Solid Queue failed executions) — a failing job
  leaves the account soft-deleted (safe state) and retryable.