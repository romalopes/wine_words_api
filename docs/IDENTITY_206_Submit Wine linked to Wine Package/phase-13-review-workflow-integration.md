# Phase 13 — Review Workflow Integration

## Status

Planned. No implementation started.

## Objective

Integrate eligible WinePackageItems with existing Wine Words review workflow: eligibility checks, catalogue matching/creation, Wine/Vintage linkage, reviewer assignment, review progress tracking, published review linkage, and submitter notifications.

## Dependencies

Phase 0, Phase 1, Phase 3, Phase 6, Phase 7, Phase 9, Phase 12

## Backend Work

### Backend Work

1. **Eligibility Checks**
   - Only items with `item_status = received` and `received_condition = good` enter review
   - Admin may record an explicit exception for an ineligible item (auditable via event)
   - Evaluated at receipt recording (Phase 12)

2. **Catalogue Matching/Creation — reuse existing editorial controls**
   - Editor matches a submitted wine to an existing Wine/Vintage, or creates new catalogue records through the existing editorial workflow
   - Submitted snapshot fields on `WinePackageItem` are always preserved (never overwritten by match)
   - Links: `wine_package_item.catalogue_wine_id`, `catalogue_vintage_id`

3. **Reviewer Assignment — reuse existing workflow**
   - Assign reviewer(s) to the matched Wine/Vintage using the existing Wine Words reviewer-assignment flow
   - No new reviewer model or assignment machinery

4. **Review Progress Tracking — derive, don't duplicate**
   - Review statuses read from the existing Review model (assigned, in_progress, published)
   - Published Review linked to the item via `wine_package_item.review_id` (column already exists)
   - Note: `WinePackageItem#reviewed?` already derives "reviewed" from the linked Review's status — reuse it

5. **Submitter Notifications**
   - Review assigned; review published
   - Via the Phase 9 notification system; milestone events recorded via `WinePackageEvent.record!` (`review_assigned`, `review_published` — the `review_published` event already exists in the item callback)

6. **Editorial Independence (non-negotiable)**
   - Payment/commercial status MUST NOT influence review score, assignment, or outcome
   - Review workflow completely separate from the commercial workflow
   - No code path may read payment/invoice state during review decisions

7. **Endpoints**
   - `GET /api/v1/admin/trade/packages/:id/items/:item_id/review-eligibility`
   - `POST /api/v1/admin/trade/packages/:id/items/:item_id/match-catalogue`
   - `POST /api/v1/admin/trade/packages/:id/items/:item_id/assign-reviewer`
   - `GET /api/v1/trade/my-packages/:id/items/:item_id/review-progress` (submitter view)

## Frontend Work

### Frontend Work

1. **Admin Review Integration** — in the Phase 7 assessment detail (or a dedicated tab)
   - Eligibility result; catalogue match/search/create UI; reviewer assignment (existing picker); progress display

2. **Submitter Review Progress** — Reviews tab in My Wine Packages (Phase 6)
   - Eligibility, catalogue match, reviewer, review status, published-review link

## Database and Migration Work

### Database and Migration Work

- No new migrations if Phases 3/12 are complete
- Ensure `wine_package_items` has `catalogue_wine_id`, `catalogue_vintage_id`, `review_id` with FKs to the existing Wine, Vintage, Review tables
- The `review_published` WinePackageEvent already exists via the item's `after_save` callback — reuse it

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

- Only eligible items enter review; Admin exceptions require an auditable event trail
- Submitted snapshots preserved regardless of catalogue match
- Review scores/outcomes never influenced by payment status (no code path may read it)
- Reviewer assignment reuses existing authorization
- Submitter sees progress only — never internal editorial details

## Testing Requirements

### Testing Requirements

1. **Request Tests**
   - Eligibility: received + good → eligible; not received → not eligible
   - Admin exception: ineligible → eligible with audit event
   - Catalogue match links correct Wine/Vintage; creation uses existing editorial controls
   - Reviewer assignment uses the existing workflow; published review linked to the item
   - Submitter sees progress; payment status provably does not affect eligibility/assignment/outcome

2. **Frontend Tests**
   - Admin eligibility display, catalogue match UI, reviewer assignment UI
   - Submitter progress view

3. **Integration Tests**
   - Full flow: receipt → eligibility → match → assign → publish → link
   - Exception flow with audit; payment-independence verification

## Deployment/Configuration Requirements

### Deployment/Configuration Requirements

- No new environment variables
- Relies entirely on existing Wine, Vintage, Review, and reviewer-assignment models

## AI Implementation Prompt

```
Integrate WinePackageItem fulfilment with the existing Wine Words review workflow.

Requirements:
- Only eligible received items (item_status = received, received_condition = good) enter review
- Admin exception for ineligible items, recorded as an auditable WinePackageEvent
- Match/create catalogue records through the EXISTING editorial controls
- Preserve the submitted snapshot fields on WinePackageItem (never overwritten by match)
- Link WinePackageItem to catalogue Wine/Vintage (catalogue_wine_id, catalogue_vintage_id)
- Assign reviewer(s) using the EXISTING reviewer-assignment workflow
- Track review progress by deriving from the existing Review model — do not duplicate status logic
  (WinePackageItem#reviewed? already derives reviewed state from the linked Review)
- Link the published Review to the package item (review_id — column already exists)
- Notify the submitter at milestones (Phase 9)
- Payment status MUST NOT influence review eligibility, assignment, or outcome

Deduplication constraints (from Phase 1):
- REUSE existing Wine, Vintage, Review models and reviewer-assignment workflow — do NOT create
  a parallel review system
- REUSE the existing WinePackageItem#record_review_published_event callback that records the
  review_published WinePackageEvent — add review_assigned alongside it, not a new store
- The review_id column already exists on wine_package_items; do not re-add it

Deliver:
- Eligibility check service
- Catalogue match/create integration (admin endpoints)
- Reviewer assignment integration
- Review progress tracking (derived) and published-review linkage
- Submitter notifications
- Admin UI (eligibility, matching, assignment) and submitter progress UI
- Request specs, integration tests for the full flow, payment-independence tests, frontend tests
```

## Acceptance Criteria

- [ ] Only eligible received items enter review
- [ ] Admin exception for ineligible items with audit trail
- [ ] Catalogue matching/creation uses existing editorial controls
- [ ] Submitted snapshots preserved
- [ ] WinePackageItem linked to catalogue Wine/Vintage
- [ ] Reviewer assigned via the existing workflow
- [ ] Review progress derived, not duplicated
- [ ] Published review linked to the package item
- [ ] Submitter notified at milestones
- [ ] Payment status provably does not affect review
- [ ] All tests pass

## Exit Gate

- Existing review process reused without duplicating review status or authorization logic
- Only eligible items enter review; submitted snapshots remain available
- Published reviews link correctly

## Implementation Notes

- This phase REUSES existing Wine, Vintage, Review, and reviewer-assignment functionality — no parallel review system
- Editorial independence from payment is a non-negotiable product decision (master plan §1.2)
- Verify the existing review workflow findings from the Phase 0 audit before designing integration

## Validation Results

*To be completed during execution*

- Commands executed:
- Tests run:
- Failures:
- Unresolved issues:
