# Phase 1 — Domain Design and Technical Specification

## Status

Planned. No implementation started.

## Objective

Finalise the data model, status transitions, access rules, and API contract before any migrations are created. **Reuse existing Wine Words patterns wherever possible — do not create parallel systems.**

## Dependencies

Phase 0

## Backend Work

### Domain Model Finalisation

#### 1. Existing WinePackage Model Analysis (from Phase 0 audit)

**Current associations (app/models/wine_package.rb):**
- `belongs_to :producer` (required for producer workflows)
- `belongs_to :reviewer, class_name: "User", optional: true`
- `belongs_to :created_by, class_name: "User", optional: true` — audit trail
- `belongs_to :requested_by, class_name: "User", optional: true` — **producer member who submitted the request (issue #199)**
- `belongs_to :accepted_by, class_name: "User", optional: true`
- `belongs_to :rejected_by, class_name: "User", optional: true`

**Current statuses:** `draft`, `requested`, `accepted`, `rejected`, `announced`, `in_transit`, `arrived`, `reviewing`, `completed`, `cancelled`

**Current sources:** `manual`, `unexpected`, `producer_request`, `producer_announcement`

**Current event system:** `WinePackageEvent` model exists with `event_type`, `actor`, `visibility` (shared/internal), `metadata`, `idempotency_key`

**Current item model:** `WinePackageItem` has `proposed_wine_name`, `proposed_vintage_year` for producer-submitted wines (issue #199)

#### 2. Required Extensions for Public Trade Submissions

**New source type:** Add `trade_submission` to `SOURCES` enum

**New statuses for editorial workflow:**
- `editorial_pending` — initial state for public submissions
- `assessment_in_progress` — editor reviewing
- `partially_approved` — some wines approved, some rejected/info requested
- `approved` — all wines approved, ready for commercial
- `quoted` — quote sent to submitter
- `invoiced` — invoice generated
- `paid` — payment confirmed
- `shipping_pending` — awaiting shipping address/release
- `shipping_released` — shipping instructions sent
- `received` — samples received
- (existing `completed`, `cancelled`, `rejected` reused)

**New associations for public submissions:**
- `WinePackage.submitter_id` (nullable, references User) — **different from `requested_by_id`**: `requested_by` = producer member acting for a producer; `submitter` = trade contact (winery, importer, agent) who may not have a User account initially
- Reuse existing `producer_id` (nullable) for optional producer linking
- **No new `contact_snapshot_id` column** — store contact snapshot directly on `WinePackage` as JSONB

**Contact snapshot (store on WinePackage, not separate table):**
```ruby
# Add to wine_packages:
contact_snapshot: {  # JSONB
  company_name: string,
  contact_name: string,
  email: string,
  phone: string,
  address: string,
  country: string,
  website: string,
  role: string,  # winery/importer/distributor/agent/other
  notes: string
}
```
This avoids a new table join and matches the immutable snapshot pattern.

**Extend WinePackageItem snapshot fields (reuse existing model):**
```ruby
# Add to wine_package_items (extend existing proposed_wine_name/proposed_vintage_year):
snapshot_wine_name: string       # submitted name (immutable)
snapshot_vintage: integer        # submitted vintage
snapshot_region: string
snapshot_appellation: string
snapshot_grape_varieties: string
snapshot_abv: decimal
snapshot_volume_ml: integer
snapshot_closure_type: string
snapshot_tasting_notes: text
snapshot_technical_sheet_url: string
snapshot_trade_price: decimal
snapshot_retail_price: decimal
snapshot_sample_available: boolean
snapshot_sample_quantity: integer
```
**Reuse existing:** `proposed_wine_name`, `proposed_vintage_year` → rename/alias to `snapshot_wine_name`, `snapshot_vintage` for consistency. Keep `vintage_id` for catalogue linking.

**Message system (NEW — doesn't exist):**
- `WinePackageMessage`: `wine_package_id`, `sender_id`, `sender_type` (submitter/editor/admin), `body`, `internal_note` (boolean), `created_at`
- Internal notes: Editor/Admin only (`visibility: internal`), not visible to submitter
- Attachments via ActiveStorage (reuse existing `Imageable`/`wine_package_attachments` pattern)

**Package Event/Audit — REUSE existing `WinePackageEvent`:**
- Add new `event_type` values: `trade_submitted`, `editorial_assessment`, `partial_approval`, `quote_created`, `invoice_created`, `payment_received`, `shipping_released`, `sample_received`, `review_assigned`, `review_published`, `message_sent`, `note_added`
- Reuse existing `visibility` (shared/internal), `idempotency_key`, `metadata` JSON

#### 3. Account Verification and Claiming Rules
- New email: send verification token, provision pending User on verification
- Existing email: do not reveal account existence, send secure claim link
- Token: hashed at rest, single-use, 24-hour expiry, package-scoped
- No auto-login for existing accounts

#### 4. Guest Access Tokens
- Hashed storage, expiry, revocation on package status change
- Scope: single package, read/write messages, view details

#### 5. Quote, Invoice, Payment, Shipping Boundaries
- Quote: Editor-defined service + price per approved item
- Invoice: generated from accepted quote, unique number, PDF document
- Payment: Stripe integration (or alternative), webhook-verified
- Shipping: only after payment confirmed, unless Admin override recorded

#### 6. Review Workflow Boundary
- Only eligible received items enter review
- Match/create catalogue records through existing editorial controls
- Preserve submitted snapshot
- Link published review to package
- Payment must not influence review outcome

## Frontend Work

### Frontend Specification

1. **API Contract**
   - Public submission endpoint: `POST /api/v1/trade/submissions`
   - Guest package access: `GET /api/v1/trade/packages/:token`
   - Authenticated package list: `GET /api/v1/trade/my-packages`
   - Conversation endpoints: `GET/POST /api/v1/trade/packages/:id/messages`
   - Editor assessment endpoints under `/api/v1/admin/trade/...`

2. **Authorization Matrix**
   - Anonymous: create submission, verify email, claim package (with token)
   - Submitter: view own packages, send messages, view quotes/invoices, pay
   - Editor/Admin: full assessment, commercial, shipping, conversation management
   - Cross-user access: explicitly denied

3. **Status Transition API**
   - Define allowed transitions per role
   - Validation errors for invalid transitions

## Database and Migration Work

### Database and Migration Work

1. **Migrations (no new tables for contact/events — reuse existing)**
   - Add `submitter_id` to `wine_packages` (nullable, FK to users)
   - Add `contact_snapshot` JSONB column to `wine_packages`
   - Add `source` value `trade_submission` to enum
   - Extend `status` enum with new editorial/commercial/shipping statuses
   - Add snapshot columns to `wine_package_items` (see list above)
   - Create `wine_package_messages` table (NEW)
   - **No `wine_submission_contacts` table** (use JSONB on wine_packages)
   - **No new `wine_package_events` table** (reuse existing)
   - Add indexes: `wine_packages.submitter_id`, `wine_package_items.wine_package_id`, `wine_package_messages.wine_package_id`
   - Foreign keys with appropriate `on_delete` behavior

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

1. **Authentication and Authorization**
   - Reuse existing authentication and role policies
   - Public submission endpoint narrowly scoped
   - Public users cannot set user_id, producer_id, approval status, price, invoice status, payment status, review status
   - Authenticated submitters cannot access another user's packages
   - Editors/Admins have explicit policies
   - Internal notes are staff-only
   - Producer membership permissions not inferred from submission
   - Guest tokens grant access only to one package and allowed actions
   - Strong random tokens, hashed at rest, expiry and revocation
   - No auto-login for existing accounts based on email submission

2. **Input Validation and Injection**
   - Strong parameters/explicit DTO allowlists
   - Parameter validation for all public endpoints
   - SQL injection prevention through ActiveRecord

3. **File Upload Security**
   - Attachment type/size validation
   - Private storage only
   - Signed URL expiry
   - Content type validation
   - Malware scanning if feasible

4. **Privacy and Personal Information**
   - Email verification before package claiming
   - No account enumeration via submission or claim flows
   - PII not logged in error tracking

5. **Email Security**
   - SPF/DKIM/DMARC compliance
   - No sensitive data in email bodies
   - Secure token links

6. **Payment Security**
   - Webhook signature validation
   - Idempotency keys
   - No client-trusted payment status

## Testing Requirements

### Testing Requirements

1. **Model Tests**
   - Validations for all new columns/fields
   - Status transition rules
   - Association constraints
   - Token hashing and verification

2. **Request/Integration Tests**
   - Public submission flow (valid, invalid, duplicate)
   - Email verification (new, existing, expired, replayed)
   - Package claiming (valid, invalid, expired, wrong package)
   - Guest access (valid, expired, revoked)
   - Authorization boundaries (cross-user, cross-role)
   - Status transitions (allowed, denied per role)
   - Partial approval workflow

3. **Security Tests**
   - Turnstile valid/invalid/expired/replayed/unavailable
   - Rate limit thresholds
   - File upload validation
   - Token replay attacks
   - Account enumeration attempts

## Deployment/Configuration Requirements

### Deployment/Configuration Requirements

1. **Environment Variables**
   - No new frontend variables for Phase 1
   - Backend: database migration execution
   - Existing secrets reused

## AI Implementation Prompt

```
Integrate the Trade portal domain model with the existing Wine Words codebase.

Inspect the actual repositories and the Phase 0 audit report.

Requirements:
- Map current WinePackage lifecycle and extend for public submissions
- Define nullable User/Producer associations for public submissions
- Define contact snapshot ownership (JSONB on WinePackage, NOT new table)
- Define wine item snapshot fields (extend WinePackageItem, reuse proposed_wine_name/proposed_vintage_year)
- Define message and internal-note permissions (NEW WinePackageMessage table)
- Define package event/audit structure (REUSE existing WinePackageEvent model)
- Define account verification and claiming rules
- Define guest access token security (hashed, expiry, revocation, scope)
- Define quote, invoice, payment, shipping boundaries
- Define review workflow boundary (reuse existing, no duplication)

Critical distinctions:
- submitter_id ≠ requested_by_id:
  * requested_by = producer member (authenticated, acts for their producer, issue #199)
  * submitter = trade contact (winery/importer/agent, may be anonymous, no producer membership required)
- contact_snapshot stored as JSONB on WinePackage (immutable snapshot, no join table)
- WinePackageEvent REUSED — add new event_type values, do NOT create new table
- WinePackageItem EXTENDED — reuse proposed_wine_name/proposed_vintage_year as snapshot_* fields
- Only NEW table: WinePackageMessage (conversation between submitter and editors)

Deliver:
- Finalised domain model diagram
- Status transition matrix with role permissions
- API contract (endpoints, parameters, responses, errors)
- Proposed migrations with up/down
- Authorization policy matrix
- Security threat model for public endpoints
- Test plan for all new flows

Do not generate migrations yet. Produce a technical specification document.
```

## Acceptance Criteria

- [ ] WinePackage lifecycle fully mapped with new statuses
- [ ] Nullable submitter/Producer associations defined (submitter_id ≠ requested_by_id)
- [ ] Contact snapshot stored as JSONB on WinePackage (no new table)
- [ ] Wine item snapshot fields extend WinePackageItem (reuse proposed_wine_name/proposed_vintage_year)
- [ ] Message and internal-note permissions defined (NEW WinePackageMessage table)
- [ ] Package event/audit structure REUSES existing WinePackageEvent model
- [ ] Account verification and claiming rules defined
- [ ] Guest token security specified
- [ ] Quote/invoice/payment/shipping boundaries defined
- [ ] Review workflow boundary documented
- [ ] API contract documented
- [ ] Authorization matrix complete
- [ ] Proposed migrations listed (no wine_submission_contacts, no new wine_package_events table)
- [ ] Security threat model for public endpoints documented
- [ ] Test plan covers all new flows

## Exit Gate

- Domain model, lifecycle, permissions, and API contract are approved and internally consistent
- No migrations created yet
- Phase 1 specification document completed

## Implementation Notes

- This phase is design-only; no code generation
- All decisions must be traceable to Phase 0 audit findings
- **Reuse existing Wine Words patterns wherever possible**
- **Do not create parallel systems** — no WineSubmissionContact table, no new WinePackageEvent table
- `submitter_id` is distinct from `requested_by_id` (producer member vs trade contact)
- Contact snapshot as JSONB avoids join and matches immutable snapshot pattern
- Extend WinePackageItem rather than creating WineSubmissionItem

## Validation Results

### Final implementation decisions (after Phase 0 audit)

1. **`producer_id` nullable:** migration changes `wine_packages.producer_id` to `null: true`; `WinePackage#producer` becomes `optional: true`. Producer-facing validations stay conditional on source.
2. **Password setup reuses Devise:** `users.reset_password_token` + Devise reset flow replaces a bespoke "password setup token" — no new user columns for verification/password.
3. **Email verification reuses `EmailVerificationService`** (digest, single-use, expiry) and the existing public verify endpoint.
4. **Claim = `submitter_id` link:** `POST /api/v1/trade/packages/:token/claim` (authenticated) links the package to the current user and revokes the guest token. Works logged-in-click and login-then-claim.
5. **Shipping reuses existing tracking** (`wine_packages.tracking_*` columns + `ShipmentTracking`/`ShipmentTrackingEvent`) — no `wine_package_shipments` table. Shipping address stored as JSONB `shipping_address` on the package (mirrors `contact_snapshot`).
6. **Stripe webhook reuses `Api::V1::WebhooksController#stripe` + `BillingEvent.claim`** idempotency — no `stripe_webhook_events` table. Trade checkout sessions carry `metadata.trade_invoice_id`.
7. **Guest token:** `guest_token_digest` (hashed), `guest_token_expires_at`, `guest_token_revoked_at` on `wine_packages`.
8. **Snapshot aliases:** `snapshot_wine_name`/`snapshot_vintage` are Ruby alias methods over the existing `proposed_wine_name`/`proposed_vintage_year` columns — no destructive rename migration.
9. **New tables only:** `wine_package_messages`, `wine_package_quotes`, `wine_package_invoices`.

### Status

Design finalised per the above; implementation begins in Phase 2/3.

### Unresolved issues
- None.
