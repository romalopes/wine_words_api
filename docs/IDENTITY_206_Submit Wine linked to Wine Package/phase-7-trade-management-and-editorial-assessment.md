# Phase 7 — Trade Management and Editorial Assessment

## Status

Planned. No implementation started.

## Objective

Implement Editor/Admin workflows: submission queue, assessment, approve/reject/request-information, partial approval, producer matching, internal notes, and audit trail. **Use new editorial statuses (`editorial_pending`, `assessment_in_progress`, `partially_approved`, `approved`, `rejected`) and REUSE existing `WinePackageEvent` for audit trail.**

## Dependencies

Phase 0, Phase 1, Phase 3, Phase 6

## Backend Work

### Backend Work

1. **Admin Namespace Routes**
   - `GET /api/v1/admin/trade/packages` — queue with filters
   - `GET /api/v1/admin/trade/packages/:id` — assessment detail
   - `PATCH /api/v1/admin/trade/packages/:id/assess` — submit assessment
   - `POST /api/v1/admin/trade/packages/:id/match-producer` — producer matching
   - `POST /api/v1/admin/trade/packages/:id/internal-notes` — add internal note

2. **Submission Queue**
   - Filters: status (`editorial_pending`, `assessment_in_progress`, `partially_approved`, `approved`, `rejected`), date range, submitter email, producer match
   - Sorting: oldest first, priority
   - Pagination
   - Summary counts per status

3. **Assessment Detail**
   - Package info, contact snapshot (from JSONB), all wines with snapshot data
   - Per-wine decision: `approve`, `reject`, `request_information`
   - Partial approval: approve subset, reject others, request info on rest
   - Internal notes section (staff only)
   - Producer matching UI

4. **Assessment Submission**
   - Validates: at least one decision per wine
   - Updates item statuses: `pending` → `approved`/`rejected`/`information_requested`
   - Updates package status: `editorial_pending` → `assessment_in_progress` → `partially_approved` / `approved` / `rejected`
   - Records `WinePackageEvent` via `WinePackageEvent.record!` for each decision (types: `editorial_assessment`, `partial_approval`)
   - Sends notification to submitter (Phase 10)
   - Creates quote for approved items (Phase 11)

5. **Producer Matching**
   - Search existing Producers by name, address, country
   - Link package to Producer (`wine_packages.producer_id`)
   - Does NOT grant ProducerMembership
   - Records `WinePackageEvent` (type: `producer_matched`)

6. **Internal Notes**
   - Separate from submitter messages (Phase 9)
   - Editor/Admin only
   - Not visible in submitter API/frontend
   - Records `WinePackageEvent` (type: `note_added`, visibility: `internal`)

7. **Audit Trail — REUSE existing `WinePackageEvent`**
   - All assessment actions recorded via `WinePackageEvent.record!`
   - Actor, timestamp, decision, metadata
   - Reuse existing `visibility` (shared/internal), `idempotency_key`, `metadata` JSON

## Frontend Work

### Frontend Work

1. **Admin Trade Management Pages**
   - Route: `/admin/trade/packages` (Editor/Admin only)
   - Queue table: reference, submitter, status, wine count, submitted date, actions
   - Filters sidebar
   - Bulk actions (optional)

2. **Assessment Detail Page**
   - Route: `/admin/trade/packages/:id`
   - Package header: reference, status, submitter contact (from JSONB contact_snapshot)
   - Wine list with snapshot data and decision radios (approve/reject/request_info)
   - Partial approval: select multiple, apply same decision
   - Information request: free text per wine
   - Internal notes panel (collapsible, staff only)
   - Producer matching search and link
   - Submit assessment button

3. **Authorization**
   - Route guards for Editor/Admin roles
   - API policy checks

## Database and Migration Work

### Database and Migration Work

- No new migrations if Phase 3 complete
- Ensure indexes on `wine_packages.status`, `wine_packages.producer_id`, `wine_package_items.item_status`
- Status enum already extended in Phase 3

## API and Authorization Requirements

- Reuse existing authentication and role policies
- Public endpoints narrowly scoped
- Object-level authorization for package access
- Editor/Admin explicit policies for assessment/commercial actions
- Internal notes staff-only
- Guest tokens: single package, scoped permissions, hashed, expiry, revocation
- No auto-login for existing accounts based on email submission

## Security Requirements

### Security Requirements

- Editor/Admin authorization required for all endpoints
- Internal notes never exposed to submitter API (visibility: internal)
- Producer matching does not grant membership
- Partial approval preserves original snapshots (JSONB contact_snapshot, WinePackageItem snapshot fields)
- Assessment decisions recorded in audit trail via `WinePackageEvent.record!`
- Cross-package access denied

## Testing Requirements

### Testing Requirements

1. **Request Tests**
   - Queue filters, pagination, sorting work
   - Assessment detail returns all data including JSONB contact_snapshot
   - Assessment submission updates statuses correctly (`editorial_pending` → `assessment_in_progress` → `partially_approved`/`approved`/`rejected`)
   - Partial approval works (mix of decisions)
   - Information request recorded per wine
   - Producer matching links producer (no membership grant)
   - Internal notes created and staff-only
   - Events recorded via `WinePackageEvent.record!` for all actions
   - Notifications triggered (Phase 10)
   - Quote creation triggered (Phase 11)

2. **Frontend Tests**
   - Queue page renders with filters
   - Assessment page shows all wines with decision controls
   - Partial approval UI works
   - Internal notes panel staff-only
   - Producer search works
   - Authorization: non-editor redirected

3. **Authorization Tests**
   - Submitter cannot access admin endpoints
   - Reader/Reviewer cannot access
   - Editor/Admin can access
   - Internal notes not in submitter API

## Deployment/Configuration Requirements

### Deployment/Configuration Requirements

- No new environment variables
- Admin routes protected by existing role middleware

## AI Implementation Prompt

```
Implement the Trade Management and editorial assessment workflow for Wine Words Editors and Admins.

Requirements:
- Admin queue with filters, pagination, sorting (new statuses: editorial_pending, assessment_in_progress, partially_approved, approved, rejected)
- Assessment detail with per-wine decisions (approve/reject/request_info)
- Partial approval (mixed decisions per package)
- Producer matching (link only, no membership grant)
- Internal notes (staff-only, visibility: internal)
- Audit trail via WinePackageEvent.record! (REUSE existing model)
- Notification triggering on assessment
- Quote creation triggering for approved items
- Authorization: Editor/Admin only

Key design points:
- Status transitions: editorial_pending → assessment_in_progress → partially_approved / approved / rejected
- Contact snapshot from JSONB contact_snapshot on WinePackage
- WinePackageItem snapshot fields used for assessment (immutable)
- WinePackageEvent REUSED — call WinePackageEvent.record! with new event types
- Internal notes separate from Phase 9 conversations (visibility: internal)

Deliver:
- Admin API endpoints (queue, detail, assess, match-producer, internal-notes)
- Admin frontend pages (queue, assessment detail)
- Authorization policies
- Request specs for all endpoints
- Frontend component tests
- Authorization tests
```

## Acceptance Criteria

- [ ] Admin queue loads with filters, pagination, sorting for new statuses
- [ ] Assessment detail shows all wines with JSONB contact_snapshot and snapshot fields
- [ ] Per-wine decisions: approve, reject, request_information
- [ ] Partial approval works (mixed decisions)
- [ ] Information request recorded per wine
- [ ] Producer matching links producer (no membership grant)
- [ ] Internal notes created, staff-only (visibility: internal)
- [ ] Events recorded via WinePackageEvent.record! for all actions
- [ ] Package status transitions correctly (editorial_pending → assessment_in_progress → partially_approved/approved/rejected)
- [ ] Notifications triggered
- [ ] Quote creation triggered for approved items
- [ ] Authorization: only Editor/Admin access
- [ ] Internal notes not exposed to submitter
- [ ] All tests pass

## Exit Gate

- Editors can manage submissions without granting unintended Producer membership or exposing staff-only data
- Partial approval works correctly
- Audit trail complete via existing WinePackageEvent model
- Integration with notifications and quotes triggered

## Implementation Notes

- Reuse existing Wine Words admin patterns and authorization
- Producer matching should search existing Producers, not create new ones
- Internal notes are separate from Phase 9 conversations (visibility: internal vs shared)
- Preserve original submission snapshots (JSONB contact_snapshot, WinePackageItem snapshot fields) regardless of assessment outcome
- WinePackageEvent REUSED — no new table, just new event_type values

## Validation Results

*To be completed during execution*

- Commands executed:
- Tests run:
- Failures:
- Unresolved issues:
