# Phase 3 — Public Submission Backend and WinePackage Integration

## Status

Planned. No implementation started.

## Objective

Implement the public submission backend: create WinePackage from anonymous submission, persist contact snapshot as JSONB, store multiple wine item snapshots (extending WinePackageItem), set editorial_pending status, and integrate with existing WinePackage domain. **Reuse existing models — no parallel systems.**

## Dependencies

Phase 0, Phase 1, Phase 2

## Backend Work

### Backend Work

1. **Public Submission Endpoint**
   - `POST /api/v1/trade/submissions`
   - Accepts: contact_snapshot, wines[], service_details, declaration
   - Validates: Turnstile token (Phase 4), required fields, wine count (1+)
   - Creates: WinePackage (with JSONB contact_snapshot), WinePackageItems (extended)
   - Sets status: `editorial_pending`
   - Returns: package reference, guest access token
   - Idempotency key support (client-generated)

2. **Models and Associations**
   - `WinePackage`: `submitter_id` (nullable, User), `contact_snapshot` (JSONB), `source` = `trade_submission`, `status` extended with editorial_pending, assessment_in_progress, partially_approved, approved, rejected, quoted, invoiced, paid, shipping_pending, shipping_released, received, completed
   - **No `WineSubmissionContact` table** — contact data stored as JSONB on WinePackage
   - `WinePackageItem` (extend existing): reuse `proposed_wine_name`/`proposed_vintage_year` as `snapshot_wine_name`/`snapshot_vintage`, add remaining snapshot fields (region, appellation, grape_varieties, abv, volume_ml, closure_type, tasting_notes, technical_sheet_url, trade_price, retail_price, sample_available, sample_quantity), `catalogue_wine_id`, `catalogue_vintage_id`, `review_id`, `item_status` (pending, approved, rejected, information_requested, matched, shipped, received)

3. **Validation and Strong Parameters**
   - Explicit allowlist for public submission parameters
   - Nested attributes for contact and wines
   - No mass assignment for: user_id, producer_id, status, price, invoice_status, payment_status, review_status

4. **Submission Idempotency**
   - Client provides `idempotency_key` header
   - Store key with package reference (24h TTL)
   - Return existing package on duplicate key

5. **Event/Audit Recording — REUSE existing `WinePackageEvent`**
   - Call `WinePackageEvent.record!` on submission with type `trade_submitted`
   - Actor: `anonymous_submitter` (nullable actor)
   - Metadata: submission IP (hashed), Turnstile verification result
   - Reuse existing `idempotency_key`, `visibility`, `metadata` JSON

6. **No Automatic Catalogue Publication**
   - Submitted wines do not create Wine/Vintage records
   - Matching happens in Phase 8/14 by Editors

7. **No Automatic Producer Membership**
   - Producer matching in Phase 8 does not grant membership

## Frontend Work

- No frontend work in this phase (Phase 5 implements the submission form)
- Backend API must be ready for Phase 5 integration

## Database and Migration Work

1. **Migrations (reuse existing models — no parallel tables)**
   - Add columns to `wine_packages`: `submitter_id` (nullable, FK to users), `contact_snapshot` (JSONB), add `trade_submission` to `source` enum, extend `status` enum with new editorial/commercial/shipping statuses
   - Add snapshot columns to `wine_package_items` (extend existing `proposed_wine_name`/`proposed_vintage_year` → rename/alias to `snapshot_wine_name`/`snapshot_vintage`, add remaining fields)
   - Create `wine_package_messages` table (NEW — only genuinely new table)
   - **No `wine_submission_contacts` table** (use JSONB on wine_packages)
   - **No new `wine_package_events` table** (reuse existing WinePackageEvent model)
   - Add indexes: `wine_packages.submitter_id`, `wine_package_items.wine_package_id`, `wine_package_messages.wine_package_id`
   - Foreign keys with appropriate `on_delete` behavior

2. **Data Migration**
   - If existing `wine_packages` need default status values, backfill
   - Rename `proposed_wine_name` → `snapshot_wine_name`, `proposed_vintage_year` → `snapshot_vintage` for consistency (or add alias methods)
## API and Authorization Requirements

- Reuse existing authentication and role policies
- Public endpoints narrowly scoped
- Object-level authorization for package access
- Editor/Admin explicit policies for assessment/commercial actions
- Internal notes staff-only
- Guest tokens: single package, scoped permissions, hashed, expiry, revocation
- No auto-login for existing accounts based on email submission

## Security Requirements

1. **Public Endpoint Hardening**
   - Narrow parameter allowlist
   - No sensitive field assignment
   - Turnstile verification (Phase 4) required before processing
   - Rate limiting (Phase 4) applied

2. **Data Protection**
   - Contact email stored in JSONB but not exposed in API responses except to owner/editor
   - Guest token hashed at rest
   - No PII in logs

3. **Authorization**
   - Public endpoint: no authentication, but Turnstile-verified
   - Cannot set: user_id, producer_id, approval status, price, invoice_status, payment_status, review_status

## Testing Requirements

1. **Model Tests** - WinePackage status transitions, WinePackageItem snapshot field validations, association constraints (no WineSubmissionContact)
2. **Request Tests** - Valid submission creates package/items/events (via WinePackageEvent.record!), invalid returns 422, missing fields rejected, zero wines rejected, duplicate idempotency returns existing, status editorial_pending, guest token generated, event recorded, cannot set protected fields
3. **Integration Tests** - Full submission flow with valid data, multiple wines in one package, special characters in text fields, large payload handling

## Deployment/Configuration Requirements

- Run migrations before deploying endpoint
- Ensure Turnstile secret configured (Phase 4)
- Rate limit store (Redis) available

## AI Implementation Prompt

```
Implement the public submission backend for the Wine Words Trade portal.

Requirements:
- POST /api/v1/trade/submissions endpoint
- Accepts contact snapshot, multiple wines, service details, declaration
- Creates WinePackage with editorial_pending status, source=trade_submission, contact_snapshot (JSONB)
- Creates WinePackageItems with snapshot fields (extend WinePackageItem, reuse proposed_wine_name/proposed_vintage_year as snapshot_*)
- Generates guest access token (hashed, 24h expiry, package-scoped)
- Records WinePackageEvent via WinePackageEvent.record! with type=trade_submitted
- Idempotency key support
- Strong parameter allowlist (no mass assignment of protected fields)
- Turnstile verification required (integrate with Phase 4)
- Rate limiting applied (integrate with Phase 4)
- No automatic catalogue record creation
- No automatic Producer membership

Critical deduplication:
- NO WineSubmissionContact table — use JSONB contact_snapshot on WinePackage
- NO new WinePackageEvent table — REUSE existing WinePackageEvent model, call WinePackageEvent.record! with type=trade_submitted
- WinePackageItem EXTENDED — reuse proposed_wine_name/proposed_vintage_year as snapshot_wine_name/snapshot_vintage
- Only NEW table: wine_package_messages (Phase 9)

Deliver:
- Controller with endpoint
- Model validations and associations
- Migrations (no wine_submission_contacts, no new wine_package_events)
- Request specs for all success and failure cases
- Security test for protected field assignment
- Idempotency test
```

## Acceptance Criteria

- [ ] Anonymous user can create valid multi-wine package
- [ ] Package status is editorial_pending
- [ ] Package source is trade_submission
- [ ] Contact snapshot persisted as JSONB on WinePackage (no separate table)
- [ ] Multiple wine items stored with snapshot fields (extending WinePackageItem)
- [ ] Guest access token generated and returned
- [ ] Submission event recorded via WinePackageEvent.record! (type=trade_submitted)
- [ ] Idempotency key prevents duplicate packages
- [ ] Protected fields cannot be set via public endpoint
- [ ] Turnstile verification enforced
- [ ] Rate limiting applied
- [ ] All request specs pass

## Exit Gate

- An anonymous user can create a valid multi-wine package safely
- All model validations and associations work
- API contract matches Phase 1 specification (deduplicated design)
- Tests pass

## Implementation Notes

- This phase depends on Phase 4 (Turnstile/rate limiting) for production readiness
- Can be developed in parallel with Phase 4 but integration required before release
- **Reuse existing WinePackage and WinePackageEvent models — no parallel systems**
- `submitter_id` is distinct from `requested_by_id` (producer member vs trade contact)
- Contact snapshot as JSONB avoids join and matches immutable snapshot pattern
- Extend WinePackageItem rather than creating WineSubmissionItem