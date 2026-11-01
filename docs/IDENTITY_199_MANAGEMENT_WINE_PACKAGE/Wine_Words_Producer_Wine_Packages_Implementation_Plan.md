# Wine Words — Producer Wine Package Management Implementation Plan

**Date:** 2026-10-31  
**Projects:** `romalopes/wine_words_api` (Rails), `romalopes/wine_words_frontend` (React)  
**Status:** Backend implementation in progress — Phases 0–5 (API repository) implemented and tested on 2026-11-01 (see §13 Implementation record). Frontend phases 6–7, notifications hardening (§8) and rollout (§10) remain open.  

**Goal:** Allow ordinary authenticated users with an authorized relationship to a producer to request wine packages, attach photos and documents, supply shipping/post-office information, and follow shipment and editorial progress without granting global editorial permissions.

## 0. Existing architecture and constraints

Existing design notes indicate `WinePackage`, `WinePackageItem`, `ShipmentTracking`, `ShipmentTrackingEvent`, request/accept/reject and shipping/review lifecycle states, review progress, reminders, and an Australia Post integration. The previous assessment identified `WinePackageAuthorizable`, `ProducerMembership`, and React package pages as likely integration points. **These are starting hypotheses, not a verified line-by-line audit of the current repository.**

Before implementation, inspect the current migrations, models, associations, serializers, controllers, routes, policies/concerns, background jobs, mailers, frontend routes/components, tests, and docs. Reuse existing behavior; do not create parallel systems.

### Product principles

1. Producer access derives from **active, approved management membership** in `ProducerMembership`, never from following a producer or the global `Reader` role alone.
2. A user may manage packages for several producers; access is checked per package and per action.
3. Shipping progress and editorial progress are **separate views**, even if the existing lifecycle remains one database status field.
4. Producer-facing data excludes internal notes, confidential drafts, unpublished scores, private contact details, and editorial-only attachments.
5. Carrier-delivered does not mean physically received by Wine Words; arrival requires authorized confirmation.
6. Preserve existing editorial/reviewer flows and API contracts; prefer additive, backward-compatible changes.
7. All sensitive operations are server-authorized; the frontend is not a security boundary.
8. Prefer existing Active Storage/R2, notification/email, and tracking services.

## 1. End-to-end user journeys

### Producer representative

1. Log in as an ordinary user associated with one or more producers.
2. Navigate to **My Wine Packages** or Producer → **Wine Packages**.
3. Select an eligible producer; create a **draft** package request.
4. Add existing catalog wines/vintages or proposed wines not yet in the catalog, quantities, notes, and bottle photos.
5. Add optional documents (technical sheets, tasting notes), review request details, and shipping instructions.
6. Submit; see **Requested / Awaiting editorial decision**.
7. Receive acceptance/rejection with a producer-visible reason when rejected.
8. After acceptance, enter carrier, tracking number, dispatch date, parcel count, postal receipt/label and parcel photos.
9. Follow carrier events and the application activity timeline.
10. See physical arrival confirmation, high-level editorial milestones, per-item progress, and links to published reviews.
11. Optionally cancel before a defined cutoff; retain history.

### Editor/admin

Review request, validate wines and producer relationship, accept/reject with reason, assign reviewer, confirm receipt, link/create catalog wines, manage review deadlines and internal notes, publish reviews, close package.

### Reviewer

See assigned packages, confirm arrival if authorized by existing policy, work on reviews, and retain existing permissions without inadvertently acquiring producer-wide rights.

## 2. Proposed permissions matrix (confirm membership enum in audit)

| Action | Producer owner/manager* | Editor/Admin | Assigned reviewer | Other authenticated user |
|---|---|---|---|---|
| List/view producer's packages | Yes | Yes | Assigned | No |
| Create/edit own draft | Yes | Yes | Existing rules | No |
| Submit request | Yes | Yes | Existing rules | No |
| Add/edit draft items and attachments | Yes | Yes | Existing rules | No |
| Add shipment details after acceptance | Yes | Yes | Existing rules | No |
| View producer-safe events and progress | Yes | Yes | Assigned | No |
| Withdraw pending request | Conditional | Yes | No | No |
| Accept/reject request | No | Yes | No | No |
| Assign reviewer/change deadlines | No | Yes | Existing rules | No |
| Confirm physical receipt | No | Yes | If existing policy permits | No |
| Read internal notes/draft reviews | No | Yes | Existing rules | No |
| Publish review | No | Existing rules | Existing rules | No |
| Hard delete package | No | Admin only if safe | No | No |

*Use actual `membership_type` values after audit. Verify active status, invitation acceptance, producer association, and any existing RBAC overrides. Recheck access on every request, including attachment downloads and background job callbacks.

## 3. Proposed data model — additive and conditional

**Do not migrate blindly.** First identify which columns, enums, attachments, and associations already exist.

### WinePackage

Keep existing `producer_id`, creator/reviewer associations, lifecycle, source, timestamps, deadlines, and review progress. Candidate fields only if absent:

- `requested_by_id` (only if existing `created_by_id` cannot represent requester)
- `submitted_at` (if not equivalent to `requested_at`)
- `producer_reference` (optional string)
- `producer_notes` (text; producer-visible)
- `shipping_notes` (text; producer-visible)
- `internal_notes` (text; editorial-only, preferably existing facility)
- `lock_version` (optional optimistic locking for conflicting edits)

Use existing source enum (e.g. `producer_request`) if present. For drafts, determine whether an existing draft state works; otherwise add one with explicit migration/transition compatibility.

### WinePackageItem

Reuse existing association and catalog linking. Allow `vintage_id` to be absent only where current validations permit; store a proposed wine name, vintage year, quantity, and producer-supplied description as needed. Do not create duplicate `Wine` records on submission. Validate quantities and ownership of selected wines/vintages.

### WinePackageAttachment (recommended if metadata required)

- `wine_package_id` (required), `wine_package_item_id` (nullable)
- `uploaded_by_id` (required)
- `attachment_type` (`bottle_photo`, `parcel_photo`, `postal_receipt`, `shipping_label`, `technical_sheet`, `tasting_notes`, `other`)
- `visibility` (`shared`, `internal`)
- `caption`, timestamps
- `has_one_attached :file` using existing Active Storage/R2

Alternative: `has_many_attached :attachments` only if categorization, per-item association, ownership, and visibility are unnecessary. Validate content type, file size, count, file ownership, signed URL authorization and metadata. Do not store public permanent R2 URLs.

### WinePackageEvent (recommended)

- `wine_package_id`, `actor_id` nullable for system/carrier
- `event_type`, `description` or localization key, JSON metadata
- `visibility` (`shared`, `internal`), `occurred_at`, timestamps
- Optional `idempotency_key` unique per package for provider callbacks

Store app activity (requested, accepted, tracking added, arrival confirmed, review published); **do not duplicate raw** `ShipmentTrackingEvent` data. Build a unified timeline projection across both event sources.

### ShipmentTracking

Reuse carrier, tracking number, provider, status and event associations. Add optional dispatch date, parcel count, receipt reference only if missing. Consider multi-parcel shipments: explicitly decide whether one package may have many tracking numbers. If yes, prefer multiple tracking records rather than comma-separated values.

### Comments (later phase)

Prefer existing polymorphic comment infrastructure if available. Add `shared`/`internal` visibility and appropriate notification behavior; avoid accidentally exposing editorial notes.

## 4. API contract (adapt to existing route conventions)

Prefer extending existing package endpoints, not duplicating them under a separate producer controller unless that makes authorization and scoping clearer.

| Method | Candidate endpoint | Purpose |
|---|---|---|
| GET | `/api/wine_packages?producer_id=&status=&page=` | Scoped listing; server filters by permission |
| GET | `/api/wine_packages/:id` | Producer-safe or editorial serializer by policy |
| POST | `/api/wine_packages` | Create draft for authorized producer |
| PATCH | `/api/wine_packages/:id` | Update permitted draft fields |
| POST | `/api/wine_packages/:id/submit` | Validate and submit request |
| POST | `/api/wine_packages/:id/withdraw` | Conditional withdrawal |
| POST | `/api/wine_packages/:id/items` | Add wine/item |
| PATCH/DELETE | `/api/wine_package_items/:id` | Edit/remove permitted item |
| POST | `/api/wine_packages/:id/attachments` | Upload permitted file |
| DELETE | `/api/wine_package_attachments/:id` | Remove own allowed attachment |
| POST/PATCH | `/api/wine_packages/:id/shipment_trackings` | Add/update shipment info |
| GET | `/api/wine_packages/:id/timeline` | Authorized merged events |
| GET | `/api/wine_packages/:id/progress` | Safe aggregate and per-item editorial status |

Use the project's actual API prefix, naming, pagination and response conventions. Maintain existing accept/reject/arrive/reviewer endpoints. Return consistent `401` unauthenticated, `403` unauthorized, `404` for hidden resource where convention requires, `422` invalid transitions/inputs, `409` conflicts. Reject unpermitted fields rather than mass-assigning them. Protect against forged producer IDs, attachment IDs and tracking IDs. Paginate lists and events.

### Example producer-safe detail response (illustrative)

```json
{
  "id": 125,
  "producer": { "id": 12, "name": "Example Winery" },
  "status": "reviewing",
  "shipping": { "carrier": "Australia Post", "tracking_number": "EXAMPLE123" },
  "items": [
    { "id": 81, "wine_name": "Shiraz", "vintage_year": 2023, "review_status": "published", "published_review_url": "/reviews/example" },
    { "id": 82, "wine_name": "Chardonnay", "vintage_year": 2024, "review_status": "in_progress" }
  ],
  "review_progress": { "published": 1, "total": 2 }
}
```

No draft content, scores, private reviewer comments or editorial-only attachments in producer serializer.

## 5. Phase-by-phase implementation and AI prompts

Run each prompt separately, review the diff, run tests, then commit before proceeding. Ask the AI coding agent to cite exact changed files and to avoid inventing models or APIs.

### Phase 0 — Repository audit and baseline

**Tasks:** Inspect current API/frontend, read `docs/architecture/wine_packages.md`, map lifecycle and permissions, document actual membership types and existing tests. Record baseline test failures and schema. Decide which proposed fields/features already exist.

**Acceptance:** A concise verified inventory, gap analysis, endpoint map, and migration plan; no production code changes.

**AI prompt:**

> Audit `wine_words_api` and `wine_words_frontend` on the current branch for producer-managed Wine Packages. Inspect routes, `WinePackage`, `WinePackageItem`, `ProducerMembership`, authorization concerns/policies, shipment tracking models/providers/jobs, Active Storage, notifications, serializers, React package pages, and tests. Read the architecture docs but verify them against code. Produce a file-by-file inventory, exact current state transitions, existing role/membership values, security gaps, missing UI and tests, and a minimal additive implementation plan. Do not modify code. Mark each assumption verified or unverified.

### Phase 1 — Authorization and scoping

**Tasks:** Implement producer management membership predicate; extend existing policy/concern; scope index/show; distinguish producer-safe vs editorial fields; handle multi-producer and revoked memberships. Avoid allowing a mere follower to manage packages.

**Acceptance:** A normal logged-in member can view only authorized producer packages; unrelated users cannot read/write or enumerate them; editors/reviewers retain their existing rights.

**AI prompt:**

> Implement the minimal authorization changes needed for active producer management members to list/view Wine Packages belonging to their producers. Use the existing `ProducerMembership` schema and permission conventions. Do not create global roles or permit followers. Preserve Admin/Editor/Reviewer access. Apply server-side scoping and a producer-safe serializer. Add policy and request specs covering cross-producer IDOR, membership revocation, multiple memberships, and editorial-only field leakage. Show exact files and tests.

### Phase 2 — Producer draft and request lifecycle

**Tasks:** Reuse request transitions, add draft only if necessary, producer selection, item creation, unlisted wines, validation, submission and withdrawal rules, reject reasons. Ensure transitions are atomic and audited.

**Acceptance:** Authorized producer representative can save/submit a valid request; cannot change editorial fields or edit after submission except explicitly allowed shipment details.

**AI prompt:**

> Extend existing Wine Package creation to support producer-managed drafts and submissions. Inspect the actual status enum and workflow first; reuse existing request/accept/reject logic. Support authorized producer selection, package items, optional proposed wines absent from catalog, and safe draft edits. Introduce schema changes only when needed. Define a transition table and use transactions/idempotency where appropriate. Add model and request specs for invalid transitions, duplicate submissions, quantity validation, forged producer IDs, and prohibited editorial attributes.

### Phase 3 — Photos and documents

**Tasks:** Add metadata-bearing attachments or reuse existing attachments, direct uploads if supported, file validation, previews, deletion, visibility, storage security and cleanup. Support item-specific bottle photos and package-specific postal receipts/labels.

**Acceptance:** Producers upload allowed files to authorized packages; internal files remain invisible; invalid files rejected; orphaned blobs controlled.

**AI prompt:**

> Implement secure Wine Package and item attachments using existing Rails Active Storage and Cloudflare R2 configuration. Audit existing upload patterns. Support bottle photos, parcel photos, postal receipts, shipping labels, technical sheets and tasting notes, with uploader, category, caption and shared/internal visibility. Validate MIME/content type, size, limits and access to signed downloads; prevent cross-package attachment association and private file exposure. Add migration only if metadata model is necessary, serializers, API specs and storage tests.

### Phase 4 — Producer shipment details and tracking

**Tasks:** Allow carrier, tracking number, dispatch date, estimated arrival, parcels, shipping notes, postal receipt; reuse `ShipmentTracking` and Australia Post provider; manual carrier support; duplicate event prevention; protect editorial arrival confirmation.

**Acceptance:** Producer can add/update allowed shipment details after acceptance, track progress, and cannot mark physical arrival or alter provider event history.

**AI prompt:**

> Extend the existing Wine Package shipment tracking API for authorized producer management members. Reuse `ShipmentTracking`, `ShipmentTrackingEvent` and Australia Post integration. Add manual carrier entry and postal receipt attachment. Validate lifecycle gates, carrier/tracking inputs and ownership. Keep provider delivery events distinct from editorial receipt confirmation. Make refreshes idempotent and resilient to provider errors. Add request/service/job tests, including repeated events, bad tracking numbers, permission failures and unsupported carriers.

### Phase 5 — Activity timeline and editorial progress

**Tasks:** Add application event history if absent; merge with tracking events in read model; expose producer-safe milestones and per-item published-review status. Never expose draft scores or private editorial notes.

**Acceptance:** Ordered timeline accurately displays requests, decisions, shipment, confirmed arrival and review publication; producer can follow progress without accessing confidential material.

**AI prompt:**

> Build an auditable Wine Package activity timeline and producer-safe editorial progress API. Reuse existing audit/event infrastructure if present; otherwise introduce a small `WinePackageEvent` model with actor, type, visibility and metadata. Do not duplicate carrier tracking events. Expose a paginated merged timeline and per-item review statuses, only public review links and aggregate published counts. Ensure status transitions and events are transactionally consistent. Add visibility, ordering, duplicate-event and confidentiality tests.

### Phase 6 — Frontend producer dashboard and request wizard

**Tasks:** Add navigation under producer and My Wine Packages; eligibility-driven buttons; producer selector; draft wizard (producer → wines → attachments/notes → review/submit); list/search/filter; accessible mobile layouts; clear loading/errors; maintain editorial UI.

**Acceptance:** Reader with management membership completes request end-to-end on desktop and mobile; users without rights see no management controls; backend still enforces permissions.

**AI prompt:**

> Inspect the existing Wine Words React routes, package components, auth state, API client, forms and UI patterns. Add a producer-facing Wine Packages list/detail and a mobile-friendly four-step request wizard, reusing existing components wherever possible. Show producer selection only among eligible memberships, support catalog or proposed wines, drafts, attachments, review and submit, validation and retry. Add package navigation to producer detail and My Wine Packages. Preserve existing editorial pages and avoid introducing a second package state machine. Add component and integration tests.

### Phase 7 — Frontend tracking, progress and activity

**Tasks:** Show shipping card, tracking number/carrier, optional carrier link, timeline, delivery-vs-arrival distinction, review progress and published review links; upload postal receipt from mobile camera; refresh behavior and errors.

**Acceptance:** Producer sees accurate progress; cannot access internal notes or unpublished content; tracking API outage does not block package view.

**AI prompt:**

> Extend Wine Package detail UI with a producer-safe shipment form, tracking event timeline, application activity feed and editorial progress cards. Clearly distinguish carrier 'delivered' from Wine Words 'arrival confirmed'. Show review progress per wine and link only to published reviews. Support mobile camera/file upload, accessible status labels, loading/empty/error states, and graceful tracking provider failures. Reuse current design and add tests for each lifecycle state and confidentiality boundaries.

### Phase 8 — Notifications and communication

**Tasks:** Reuse notification/email infrastructure for requested, accepted/rejected, dispatched, arrived, review published and completed; recipient deduplication; preferences and retry. Optionally add shared/internal comments after core workflow is stable.

**Acceptance:** Relevant stakeholders receive actionable notifications once; producers never receive internal-only content; notification failures do not roll back successful package transitions.

**AI prompt:**

> Audit the existing Wine Words notifications, mailers and background jobs. Add producer/editor notifications for Wine Package submission, acceptance/rejection, shipment updates, confirmed arrival, review publication and completion. Respect recipient membership, preferences, shared/internal visibility, deduplication and retry semantics. Reuse existing comment infrastructure if suitable for optional package conversation; otherwise document comments as follow-up. Add delivery, idempotency and privacy tests. Do not send emails synchronously inside transactions.

### Phase 9 — Quality, security and regression tests

**Tasks:** Expand RSpec model/policy/request/job tests; React unit/integration tests; Playwright end-to-end flows; accessibility and mobile tests; inspect upload security, authorization, performance, pagination and audit integrity. Keep test coverage meaningful rather than chasing 100% mechanically.

**Acceptance:** No unauthorized read/write paths, existing editorial workflows pass, and all critical producer journeys have automated coverage.

**AI prompt:**

> Perform a full security and regression audit of producer Wine Package management. Build a permissions matrix test suite across Admin, Editor, Reviewer, active producer manager, inactive/revoked manager, follower and unrelated user. Exercise every endpoint including attachments, nested items, tracking, timeline and download URLs. Add Playwright scenarios for request→accept→ship→arrive→publish, rejected requests, multi-producer switching and mobile upload. Test race conditions, idempotency, background job failures, file limits, N+1 queries and serializer leakage. Run existing tests and report failures with exact commands and coverage gaps. Fix only related regressions.

### Phase 10 — Deployment, rollout and documentation

**Tasks:** Migration safety; staged rollout behind feature flag if existing flags supported; backfill only when necessary; production secrets/R2 checks; monitoring; docs; support runbook; rollback plan.

**Acceptance:** Feature can be enabled incrementally, monitored and disabled without damaging existing packages.

**AI prompt:**

> Prepare production rollout of Wine Words producer Wine Package management on Rails/Render/Neon and React/Cloudflare Pages. Audit migration reversibility, indexes, Active Storage/R2 permissions, mail and tracking credentials, API backward compatibility, feature flags, observability and error budgets. Write deployment steps, smoke tests for producer/editor/reviewer, operational runbook, support FAQ and rollback strategy. Do not deploy or change secrets automatically. Document exact commands after checking this repository's scripts and CI configuration.

## 6. Status transitions and field ownership

Verify actual enums; suggested conceptual transitions:

```text
Draft --submit--> Requested --accept--> Accepted --dispatch--> In Transit
                          | reject                     | carrier delivered
                          v                            v
                       Rejected                  Delivery reported
                                                       |
                                              confirm physical receipt
                                                       v
                                                    Arrived
                                                       |
                                              Reviewing --> Completed
```

If existing statuses include `announced`, `in_transit`, `arrived`, `reviewing`, `completed`, retain them and map the UI presentation to the actual state. A rejected request may be resubmitted only if explicitly supported; otherwise create a new request. Withdraw/cancel requires clear cutoff and event recording.

Producer-editable: own draft details/items, shared attachments, permitted shipment fields. Editorial-only: acceptance/rejection, reviewer assignment, deadlines, physical receipt, review contents/scores, internal notes, publication. Carrier-owned: imported tracking events and delivery status. Prevent mass assignment across these boundaries.

## 7. Testing matrix and quality gates

| Test layer | Critical coverage |
|---|---|
| Model | associations, validations, lifecycle, producer/item consistency |
| Policy | every membership/role/action combination, revocation, followers |
| API | scoped index/show, create, submit, nested items, tracking, attachment access |
| Service/job | atomic transitions, provider errors, retries, event deduplication |
| Serializer | producer-safe fields; no draft reviews/internal notes |
| Frontend | eligible actions, forms, mobile upload, timeline states |
| E2E | full happy path and denial paths across roles |
| Operational | storage limits, rate limiting, pagination, monitoring, rollback |

Suggested commands (confirm against project configuration):

```bash
# Rails API
bundle exec rails db:migrate
bundle exec rspec
bundle exec rubocop

# React frontend
pnpm install
pnpm test
pnpm build
pnpm exec playwright test
```

Never execute migrations against production until reviewed. Use actual package manager and scripts from `package.json`.

## 8. Security and privacy checklist

- Authorization scoped to active producer membership, not `producer_id` supplied by client.
- No cross-tenant package, item, attachment, shipment, comment, or event access.
- Never expose draft review text, private scores, internal notes or internal attachments.
- File validation, size/count limits, private object storage, authorized signed URLs.
- Avoid tracking URL injection; construct carrier links from allowlisted hosts/IDs.
- Strip unnecessary EXIF/geolocation metadata from public-facing photos where feasible.
- Avoid exposing private recipient addresses/phone numbers to producer users.
- Audit sensitive changes with actor/time and appropriate visibility.
- Rate-limit uploads, submissions and carrier polling; background retries idempotent.
- Preserve existing retention and deletion policies.

## 9. Decisions to confirm after Phase 0

1. Which actual `ProducerMembership.membership_type` values grant management rights?
2. Can all management members request packages, or only owner plus selected roles?
3. Can a producer request reviews of wines not yet registered? Recommended: yes, with proposed item metadata.
4. Can one package contain multiple parcels/tracking numbers? Recommended: yes if existing model supports it cleanly.
5. Are shipping details editable after dispatch? Recommended: limited corrections with audit trail.
6. Can a producer withdraw a request? Recommended: before acceptance, or before dispatch with editorial approval.
7. Should producer representatives see the assigned reviewer's identity? Decide based on privacy policy.
8. Should package comments ship in MVP? Recommended: no; include in second release.
9. Is offline draft saving needed immediately? Recommended: phase 2 enhancement, after secure online flow.

## 10. MVP vs follow-up

**MVP:** producer authorization, scoped lists, drafts/requests, items, bottle/parcel photos and documents, shipment details, tracking display, safe progress, timeline, essential notifications, tests.

**Later:** two-way package comments, automatic multi-carrier polling, offline draft/sync queue, package analytics, producer SLA reporting, advanced search and bulk operations.

## 11. Definition of done

- A regular authenticated user with a qualifying producer membership can create, submit and track packages for that producer only.
- Producer can add wines, photos, postal information and shipment tracking without editorial privileges.
- Editor can accept/reject and confirm physical receipt; reviewer and publication workflows remain unchanged.
- Producer sees shipment and editorial progress without confidential information.
- API, background jobs, UI, tests, migrations and docs are complete; regression and security suites pass.
- Rollout and rollback steps are documented and validated.

## 12. Repository references

- Issue: https://github.com/romalopes/wine_words_api/issues/199
- API: https://github.com/romalopes/wine_words_api
- Frontend: https://github.com/romalopes/wine_words_frontend
- Architecture notes to verify: https://github.com/romalopes/wine_words_api/blob/main/docs/architecture/wine_packages.md

## 13. Implementation record — phase references (2026-11-01)

Backend work was implemented phase by phase against issue
[romalopes/wine_words_api#199](https://github.com/romalopes/wine_words_api/issues/199).
Each phase below lists the exact files that were created or changed, so any
future contributor can trace a plan requirement to the code that fulfils it.

### Phase 0 — Repository audit and baseline

Verified against `main`; recorded the actual lifecycle (`draft` → `announced` /
`requested` → `accepted`/`rejected` → `in_transit` → `arrived` → `reviewing` →
`completed`), the `source` enum (`manual`, `unexpected`, `producer_request`,
`producer_announcement`), existing reminders (15/5/0-day) and the
`ProducerMembership` types (`owner`, `manager`, `contributor`, follower).
Audit conclusion and gap analysis are captured in the phase tasks of this
document; no production code was changed during the audit.

### Phase 1 — Authorization and scoping

Producer management derives from an active `owner`/`manager` membership — never
from following, `contributor`, or a client-supplied `producer_id`:

- `app/models/producer_membership.rb` — added `EDITABLE_TYPES`
  (`owner`/`manager`), `Managing` scope and
  `ProducerMembership.managing_producer_ids_for(user)` (used by every scope
  that enumerates producer-visible packages).
- `app/models/wine_package.rb` — added
  `scope :managed_by_producer_member(user)` on top of the existing scopes.
- `app/policies/wine_package_policy.rb` — rewritten as a four-tier policy:
  Admin/Editor (`catalogue_manager?`), assigned reviewer, created-by, and
  producer member. Adds `manage_items?`, `manage_attachments?`,
  `manage_tracking?`, `submit?`, `withdraw?`, `review?` plus a public
  `producer_member?`/`editorial_viewer?` pair so controllers and serializers
  can branch the response shape. The workflow actions (accept, reject,
  receipt, destroy) remain editorial-only — a producer member can never drive
  the editorial state machine.
- `app/controllers/concerns/wine_package_authorizable.rb` — tiered guard
  methods (`ensure_package_editable!`, `ensure_package_items_manageable!`,
  `ensure_package_attachments_manageable!`, `ensure_package_tracking_manageable!`,
  `ensure_package_withdrawable!`) mirroring the policy checks.

### Phase 2 — Producer draft and request lifecycle

- `db/migrate/20261101000001_producer_wine_package_management.rb` — additive
  migration: `requested_by_id`/`submitted_at`/`producer_reference`/
  `producer_notes`/`shipping_notes`/`internal_notes` on `wine_packages`;
  `proposed_wine_name`/`proposed_vintage_year` on `wine_package_items`;
  `dispatch_date`/`parcel_count` on `shipment_trackings`; the new
  `wine_package_attachments` and `wine_package_events` tables; and a
  per-recipient lifecycle-notification unique index replacing the
  package/type/date index that could not support multiple recipients.
- `app/models/wine_package.rb` — producer lifecycle (`request!(actor:)`,
  `withdraw!(by:, at:)`), actor provenance on `transition_to!`,
  `PRODUCER_EDITABLE_FIELDS`, and automatic `WinePackageEvent` recording
  inside `transition_to!`.
- `app/models/wine_package_item.rb` — proposal fields validated only when
  `vintage_id` is absent, so a line is always either a catalogue vintage or a
  named proposal.
- `app/services/wine_packages/submit_request.rb` and
  `withdraw_request.rb` — validated draft-only submit (rejects empty
  packages, records `submitted_at`/`requested_by`) and pending-only withdraw
  (cancelled via the existing workflow, timeline event, editors notified).
- `app/controllers/api/v1/wine_packages_controller.rb` — producer-aware
  create/update (producer members are restricted to
  `producer_create_params`/`producer_update_params`; editorial fields such as
  `notes`, `reviewer_id` and tracking snapshots are never mass-assignable from
  the producer side), plus the new `submit`, `withdraw`, `timeline` and
  `progress` actions.
- `config/routes.rb` — member routes `POST /:id/submit`, `POST /:id/withdraw`,
  `GET /:id/timeline`, `GET /:id/progress`, and nested
  `resources :attachments` under each package.

### Phase 3 — Photos and documents

- `app/models/wine_package_attachment.rb` — typed metadata row
  (`attachment_type` ∈ bottle_photo / parcel_photo / postal_receipt /
  shipping_label / technical_sheet / tasting_notes / other; `visibility` ∈
  shared / internal) with `has_one_attached :file`, a MIME allow-list
  (jpeg/png/webp/heic/pdf) and a 15 MB size cap. Bytes live in Active Storage
  (Cloudflare R2 in production); downloads are short-lived signed URLs — never
  public, permanent object URLs.
- `app/controllers/api/v1/wine_package_attachments_controller.rb` — producer
  members manage only SHARED attachments while the package is in a
  producer-manageable stage; `internal` attachments never leave the editorial
  surface; cross-package association is prevented by scoping through the
  parent package.
- `app/serializers/wine_package_attachment_serializer.rb` — per-request signed
  URL and metadata, exposed only to viewers allowed to see the attachment.

### Phase 4 — Producer shipment details and tracking

- `app/controllers/api/v1/shipment_trackings_controller.rb` — reading is as
  broad as viewing the package (404 for strangers, never a 403 that reveals
  existence); writing/refreshing is gated on `manage_tracking?`. The producer
  branch of `tracking_params` allows only `carrier`, `number`, `url` and
  `estimated_delivery_at` — never `provider`, `status` or `delivered_at`,
  which stay editorial. Refreshes remain idempotent and provider errors do not
  alter editorial state.

### Phase 5 — Activity timeline and editorial progress

- `app/models/wine_package_event.rb` — application activity rows with actor,
  type, shared/internal visibility, metadata and a per-package
  `idempotency_key` unique index; `record!` is race-safe (returns the winning
  row on `RecordNotUnique`).
- `app/services/wine_packages/timeline.rb` — merged, viewer-scoped projection
  of application and carrier events (never duplicated), chronological, with
  internal entries hidden from producer-side viewers.
- `app/services/wine_packages/notifications/lifecycle.rb` — in-app lifecycle
  notifications (submitted / withdrawn / accepted / rejected / arrived /
  completed) delivered to producer members and the editorial side.
- `app/models/notification.rb` — new `TYPES`: `wine_package_submitted`,
  `wine_package_withdrawn`, `wine_package_accepted`.

### Phase 9 (partial) — Tests written with this change

- `spec/models/wine_package_event_spec.rb` — `record!` idempotency, actor
  provenance, ordering, shared/internal visibility gates.
- `spec/models/wine_package_attachment_spec.rb` — type/MIME validation,
  visibility boundary, per-item anchoring, cascade destroy.
- `spec/requests/api/v1/shipment_trackings_spec.rb` — unrelated-user
  expectation updated to the uniform 404 visibility contract used by every
  package endpoint (a 403 would reveal that the package exists).

Result: `bundle exec rspec` — 224 examples, 0 failures.

### Still open

- **Phases 6–7** — React producer dashboard, request wizard, tracking and
  progress views (`wine_words_frontend`).
- **Phase 8** — email/preference handling for the new lifecycle notification
  types (in-app rows and types exist; mailer wiring is pending).
- **Phase 10** — rollout, monitoring and rollback documentation.



