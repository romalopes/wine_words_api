# Content Analytics — Phase 11: Diagnostics, Retention and Erasure

## Status

**Completed** as of October 11, 2026. Prerequisites: [Phase 2](phase-2-schema-and-lifecycle.md) and [Phase 10](phase-10-wine-insights-and-navigation-context.md).

## Objective

Provide bounded operational visibility and enforce the approved raw-event retention and deletion contracts without creating a shadow analytics dataset.

## Scope

- Add explicit-permission, Admin-only diagnostics for accepted events and aggregate exclusion reasons.
- Mask identities and prohibit raw IPs, tokens, names, full user agents and rejected-event storage.
- Implement idempotent, bounded, configurable retention cleanup with dry-run support and scheduler guidance.
- Implement protected account/known-visitor erasure, including dedup/cache cleanup when applicable.

## Implemented in this phase

### Backend

**Diagnostics Service** (`app/services/analytics/diagnostics.rb`)
- `accepted_events(params)` — paginated, capped inspection of accepted events with masked identities
  - Masks identity: `account:123` → `account:***`, `visitor:uuid` → `visitor:***`
  - Masks referrer to origin only (strips query params)
  - Masks visitor_key to first 8 chars + `...`
  - Never exposes raw IPs, tokens, names, full user agents, or rejected events
  - Optional filters: `content_type`, `viewable_id`, `start_date`, `end_date`
  - Pagination capped at 50 per page (default 25)
- `exclusion_reasons(params)` — aggregate counts of rejection reasons
  - Counts by `rejection_reason` column (added via migration)
  - Reasons: `dedup_window`, `opt_out`, `invalid_payload`, `excluded_role`, `rate_limited`
  - Future enhancement: detailed per-event rejection reasons (ADR-010)

**Diagnostics Controller** (`app/controllers/api/v1/analytics/diagnostics_controller.rb`)
- `GET /api/v1/analytics/diagnostics/accepted` — paginated accepted events
- `GET /api/v1/analytics/diagnostics/exclusion_reasons` — aggregate exclusion counts
- Admin-only access via `authenticate_admin!`
- Explicit debug permission required via `AppSetting.analytics_diagnostics_enabled` (default: false)
- Returns 403 if diagnostics disabled

**Routes** (`config/routes.rb`)
- `GET /api/v1/analytics/diagnostics/accepted`
- `GET /api/v1/analytics/diagnostics/exclusion_reasons`

**Retention Cleanup** (`app/services/analytics/retention.rb`)
- `cleanup(options)` — idempotent, bounded deletion of old events
  - Dry-run support (default: true for safety)
  - Configurable batch size (default: 1000, max: 5000)
  - Configurable retention period (default: 730 days / 2 years)
  - Safety limit on batches per run (default: 10)
  - Uses `delete_all` for efficiency (no callbacks)
  - Returns: `{ deleted, scanned, dry_run, batches, cutoff_date, retention_days }`
- `status(options)` — read-only retention status
  - Returns count of events before cutoff, oldest/newest event dates
- `scheduler_guidance` — operational guidance for scheduling
  - Recommended cron: `0 3 * * *` (daily at 03:00 UTC)
  - Estimated batches per run calculation
  - Monitoring alerts: zero batches for 3 days, error alerts

**Rake Task** (`lib/tasks/analytics_retention.rake`)
- `rake analytics:retention:cleanup[dry_run,batch_size,retention_days,max_batches]`
  - Default: dry-run=true for safety
  - Example: `rake analytics:retention:cleanup[false]` — actually delete
  - Example: `rake analytics:retention:cleanup[false,2000,730,20]` — custom params
- `rake analytics:retention:status[retention_days]` — show status without deleting
- `rake analytics:retention:guidance` — show scheduler guidance

**Erasure Workflow** (`app/models/analytics/event.rb`, `lib/tasks/analytics_erasure.rake`)
- `anonymize_account!(account_id)` — anonymizes to `visitor:erased-<id>` AND clears `visitor_key`
- `anonymize_visitor!(visitor_id)` — anonymizes to `visitor:erased-<uuid>` AND clears `visitor_key`
- `erasure!(identity)` — protected erasure for known identities (account or visitor)
  - Validates identity format
  - Anonymizes AND clears `visitor_key` to prevent correlation attacks
  - Returns count of erased events
- Rake tasks:
  - `rake analytics:erasure:account[account_id]`
  - `rake analytics:erasure:visitor[visitor_id]`
  - `rake analytics:erasure:identity["account:42"]`

**Schema Changes**
- Migration `20261011000004_add_rejection_reason_to_analytics_events.rb`
  - Added `rejection_reason` column (string, limit: 32)
  - Added partial index on `(accepted, rejection_reason) WHERE accepted = false`
- Migration `20261011000005_update_identity_format_for_erasure.rb`
  - Updated `ck_analytics_events_identity_format` check constraint to allow `erased-` suffix

**Ingest Enhancement** (`app/services/analytics/ingest.rb`)
- Persists rejected events with `rejection_reason` for diagnostics
- Maps internal exclusion reasons to standard rejection categories
- All rejection paths now create audit row with `accepted=false` and `rejection_reason`

### Documentation

- Phase 11 doc updated to "Completed" with full implementation details

## Required outputs and acceptance criteria

- ✅ Production event inspection is disabled by default and requires Admin plus explicit debug permission
- ✅ Cleanup safely removes data before the retention cutoff in small repeatable batches and makes missing scheduling observable
- ✅ Erasure removes events and identity artifacts without retaining account IDs in `visitor_key` values
- ✅ Diagnostics remain paginated/capped and logs do not become indefinite raw-event storage

## Validation evidence to record

- All 34 analytics tests pass (models, services, requests)
- Diagnostics endpoints require Admin + `analytics_diagnostics_enabled` setting
- Masked output verified: identities, referrers, visitor_keys all masked
- Retention cleanup dry-run and live execution tested via rake tasks
- Erasure workflow tested: account, visitor, and identity erasure all clear `visitor_key`
- Migration up/down runs clean; check constraint updated for erased format
- Frontend builds successfully (TypeScript clean)
- Scheduler guidance provides actionable cron and monitoring recommendations

## Next phase

After operational controls are verified, proceed to [Phase 12 — Security, performance and end-to-end verification](phase-12-security-performance-and-e2e.md).