# Phase 12 — Shipping and Fulfilment

## Status

Planned. No implementation started.

## Objective

Implement shipping workflow: shipping instructions, address collection at correct stage, payment gate, authorized override, shipment tracking, partial receipt, missing/damaged tracking, and fulfilment states. **Uses new statuses from Phase 3.**

## Dependencies

Phase 0, Phase 1, Phase 6, Phase 10, Phase 11

## Backend Work

### Backend Work

1. **Shipping Address Collection**
   - Collected AFTER package acceptance/payment (not in initial submission)
   - Endpoint: PATCH /api/v1/trade/my-packages/:id/shipping-address (submitter)
   - Fields: contact_name, company, address, city, region, postal_code, country, phone, instructions
   - Stored on WinePackage or separate ShippingAddress model

2. **Payment Gate**
   - Shipping instructions only sent after invoice paid
   - Check: invoice.status == paid OR admin_override == true
   - Admin override: recorded with actor, reason, timestamp

3. **Shipping Instructions Email**
   - Triggered when: paid + address provided + admin authorizes release
   - Contains: shipping address, packaging requirements, deadline, contact info
   - Sent via notification system (Phase 10)

4. **Shipment Tracking**
   - WinePackageShipment: wine_package_id, carrier, tracking_number, shipped_at, estimated_delivery, status (pending, in_transit, delivered, exception)
   - Admin creates shipment record
   - Submitter can view tracking

5. **Receipt and Fulfilment**
   - Per-item receipt: WinePackageItem status -> shipped -> received
   - Partial receipt supported
   - Missing/damaged tracking: fields on item (received_condition: good, damaged, missing; notes)
   - Admin records receipt via UI
   - Package status: shipping_pending -> shipping_released -> in_transit -> partial_received -> received

6. **Endpoints**
   - GET /api/v1/trade/my-packages/:id/shipment -- submitter view
   - POST /api/v1/admin/trade/packages/:id/shipment -- admin create
   - PATCH /api/v1/admin/trade/packages/:id/shipment -- admin update tracking
   - PATCH /api/v1/admin/trade/packages/:id/items/:item_id/receive -- admin record receipt
   - PATCH /api/v1/admin/trade/packages/:id/shipping-override -- admin override payment gate

7. **Authorization**
   - Submitter: provide address, view shipment/receipt
   - Editor/Admin: create shipment, record receipt, override gate
   - Guest token: view shipment/receipt for that package

## Frontend Work

### Frontend Work

1. **Submitter Shipping Address Form**
   - In My Wine Packages detail (Phase 7)
   - Shown after package approved/paid
   - Address form with validation
   - Save button

2. **Admin Shipment Management**
   - Route: /admin/trade/packages/:id/shipment
   - Create shipment: carrier, tracking number, estimated delivery
   - Update tracking status
   - Record per-item receipt (good/damaged/missing)
   - Override payment gate (with reason)

3. **Shipment Tracking Display**
   - Submitter view: tracking link, status, estimated delivery
   - Item-level receipt status
   - Missing/damaged indicators

## Database and Migration Work

### Database and Migration Work

1. **Migrations**
   - Add shipping address fields to wine_packages or create shipping_addresses table
   - Create wine_package_shipments table
   - Add received_condition, received_at, received_notes to wine_package_items
   - Add shipping_override_by_id, shipping_override_reason, shipping_override_at to wine_packages
   - Indexes

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

- Payment gate enforced: no shipping release without payment (unless override)
- Override requires Admin, recorded with reason, auditable
- Shipping address only collected after payment
- Address data private, only visible to submitter/admin
- Tracking numbers not sensitive but not exposed to unauthorized users

## Testing Requirements

### Testing Requirements

1. **Request Tests**
   - Address collection after payment only
   - Payment gate blocks shipping release
   - Admin override works with audit trail
   - Shipment creation and tracking
   - Per-item receipt (full, partial)
   - Missing/damaged recording
   - Package status transitions
   - Authorization boundaries

2. **Frontend Tests**
   - Address form appears at correct stage
   - Admin shipment UI works
   - Tracking display works
   - Override requires reason

3. **Integration Tests**
   - Full flow: paid -> address -> override/release -> shipment -> receipt
   - Partial receipt flow
   - Override audit trail

## Deployment/Configuration Requirements

### Deployment/Configuration Requirements

- No new environment variables
- Carrier integration optional (manual tracking entry for v1)

## AI Implementation Prompt



## Acceptance Criteria

- [ ] Shipping address collected after payment only
- [ ] Payment gate blocks shipping release without payment
- [ ] Admin override works with audit trail
- [ ] Shipment created with carrier/tracking
- [ ] Per-item receipt recorded (full/partial)
- [ ] Missing/damaged tracked per item
- [ ] Package status transitions correctly
- [ ] Submitter can provide address and view tracking
- [ ] Admin can manage shipment and override
- [ ] Notifications sent on shipping instructions and receipt
- [ ] All tests pass

## Exit Gate

- Shipping cannot be released before payment unless auditable Admin override exists
- Partial receipt and damage tracking works
- Address collection at correct workflow stage
- Integration with commercial workflow complete

## Implementation Notes

- Shipping information collected AFTER package acceptance/payment (per product decisions)
- Carrier API integration optional for v1 (manual tracking entry)
- Override must be explicit Admin action with recorded reason
- Reuse existing Wine Words notification patterns for shipping emails
- WinePackageEvent REUSED for shipping events

## Validation Results

*To be completed during execution*

- Commands executed:
- Tests run:
- Failures:
- Unresolved issues:
