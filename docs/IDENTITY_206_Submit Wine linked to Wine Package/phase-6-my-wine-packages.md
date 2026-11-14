# Phase 6 — My Wine Packages

## Status

Planned. No implementation started.

## Objective

Implement the authenticated My Wine Packages area: package list, detail view, item statuses, editorial decisions, quote/invoice status, payment status, shipping status, review progress, conversation entry, and guest access where permitted.

## Dependencies

Phase 0, Phase 1, Phase 3, Phase 5

## Backend Work

### Backend Work

1. **Authenticated Package List Endpoint**
   - `GET /api/v1/trade/my-packages`
   - Scope: packages where `submitter_id = current_user` OR user holds a valid guest token for the package
   - Pagination, filtering (status), sorting
   - Returns: id, reference, status, created_at, wine_count, latest_event

2. **Package Detail Endpoint**
   - `GET /api/v1/trade/my-packages/:id`
   - Authorization: owner (`submitter_id`) or valid guest token
   - Returns: full package, contact snapshot (JSONB), items with statuses, events (shared visibility only), messages (Phase 8), quotes/invoices (Phase 10), shipping (Phase 12), review links (Phase 13)
   - **Internal events (`visibility: internal`) and internal notes are never included**

3. **Item Statuses surfaced**
   - Each WinePackageItem: pending, approved, rejected, information_requested, matched, shipped, received
   - Editorial decisions visible per item (from Phase 7 assessment)

4. **Commercial status display**
   - Quote: draft, sent, accepted, expired, cancelled
   - Invoice: draft, sent, paid, overdue, cancelled
   - Payment: pending, confirmed, failed, refunded

5. **Shipping status display**
   - not_required, pending_payment, instructions_sent, released, in_transit, partial_received, received

6. **Review progress display**
   - not_eligible, eligible, assigned, in_progress, published (linked Review from Phase 13)

7. **Authorization**
   - Pundit policy or equivalent: user accesses only packages they own or hold a valid guest token for
   - Editors/Admins access via the separate admin namespace (Phase 7), not this one

## Frontend Work

### Frontend Work

1. **My Wine Packages List Page**
   - Route: `/trade/my-packages` (auth required)
   - Table/list: reference, status badge, submitted date, wine count, latest update
   - Status badges with colours matching the status taxonomy
   - Filter by status; pagination; empty state with CTA to `/trade/submit`

2. **Package Detail Page**
   - Route: `/trade/my-packages/:id`
   - Tabs/sections: Overview, Wines, Editorial, Commercial, Shipping, Reviews, Conversation
   - Overview: reference, status, contact snapshot, event timeline
   - Wines: item cards with status badges + snapshot details
   - Editorial: decisions, information requests, partial-approval breakdown
   - Commercial: quote status + accept button, invoice list + PDF download, payment CTA
   - Shipping: status, tracking link, per-item receipt state
   - Reviews: eligibility, catalogue match, reviewer, progress, published review link
   - Conversation: link into Phase 8 messages

3. **Guest Access View**
   - Route: `/trade/packages/:token`
   - Read-only render of the detail page; claim/verify CTAs when unauthenticated

4. **Responsiveness**
   - Card layout on mobile, table on desktop; collapsible sections; touch-friendly badges

## Database and Migration Work

- No new migrations (Phase 3 created columns; Phase 5 added guest-token fields)
- Query optimisation: indexes on `wine_packages.submitter_id`, `wine_packages.status`, `wine_package_items.wine_package_id`
- Avoid N+1: eager-load items, events, and (when present) quote/invoice/shipment/review associations

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

- Object-level authorization: user sees only own packages (`submitter_id`) or guest-token packages
- Guest tokens grant read-only access to a single package; expired/revoked tokens denied
- Editors/Admins access via the separate admin namespace only
- No cross-user package access via ID manipulation (404, not 403, to avoid existence disclosure)
- Internal events (`visibility: internal`) and internal notes excluded from all submitter/guest responses
- Payment details only shown to the package owner

## Testing Requirements

### Testing Requirements

1. **Request Tests**
   - Authenticated user sees only own packages
   - Guest token grants access to exactly one package
   - Cross-user access denied; filtering, pagination, sorting verified
   - Package detail includes all sections; internal events/notes absent
   - Expired/revoked guest token rejected

2. **Frontend Tests**
   - List renders with correct data, filters work
   - Detail shows all tabs with correct data
   - Guest view read-only with claim CTAs
   - Mobile layout verified

3. **Authorization Tests**
   - User cannot access another user's package by ID
   - Guest token cannot access a different package
   - Editor/Admin access only via admin routes

## Deployment/Configuration Requirements

### Deployment/Configuration Requirements

- No new environment variables
- Optional feature flag for phased rollout of My Wine Packages

## AI Implementation Prompt

```
Implement the My Wine Packages area for authenticated submitters and guest access in the Wine Words Trade portal.

Requirements:
- Package list with filtering, pagination, status badges, empty-state CTA
- Package detail with tabs: Overview, Wines, Editorial, Commercial, Shipping, Reviews, Conversation
- Item statuses: pending, approved, rejected, information_requested, matched, shipped, received
- Quote/invoice/payment, shipping, and review-progress status display
- Guest token read-only access to exactly one package, with claim CTAs
- Object-level authorization (owner via submitter_id or guest token only)
- Mobile responsive (cards on mobile, table on desktop)

Deduplication constraints (from Phase 1):
- REUSE existing WinePackage, WinePackageItem, WinePackageEvent models — no parallel systems
- Contact data comes from the JSONB contact_snapshot column, not a separate table
- Only expose WinePackageEvents with visibility "shared"; internal events/notes are staff-only
- submitter_id (trade contact) is the ownership link — NOT requested_by_id (producer member)
- Editors/Admins use the admin namespace (Phase 7), never these endpoints

Deliver:
- API endpoints (list, detail) with authorization policies
- Frontend list and detail pages, guest access view
- Component tests
- Authorization tests (cross-user, guest token scope, expired/revoked tokens, editor/admin separation)
- Mobile responsive tests
```

## Acceptance Criteria

- [ ] Authenticated user sees only own packages
- [ ] Package list filters, paginates, sorts
- [ ] Package detail shows all sections with correct data
- [ ] Item, commercial, shipping, and review statuses display correctly
- [ ] Guest token grants read-only access to a single package only
- [ ] Cross-user access denied; expired/revoked guest token denied
- [ ] Internal events and internal notes never appear in submitter/guest responses
- [ ] Mobile responsive layout works
- [ ] All tests pass

## Exit Gate

- Users see only packages they are authorized to access
- All status information displays correctly
- Guest access works for the claim flow
- Authorization boundaries enforced and tested

## Implementation Notes

- Reuse existing Wine Words pagination, serialization, and authorization patterns
- Commercial, shipping, and review data come from later phases — UI placeholders/sections must exist from the start
- Conversation tab links into the Phase 8 message components
- Return 404 (not 403) for unauthorized package IDs to avoid existence disclosure

## Validation Results

*To be completed during execution*

- Commands executed:
- Tests run:
- Failures:
- Unresolved issues:
