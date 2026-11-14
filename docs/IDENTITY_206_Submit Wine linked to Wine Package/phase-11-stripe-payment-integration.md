# Phase 11 — Stripe Payment Integration

## Status

Planned. No implementation started.

## Objective

Implement Stripe payment integration for invoice payment: checkout session, payment intent, webhook handling, idempotency, replay protection, payment status transitions, and refund/failure handling. **Updates package status to `paid` on success.**

## Dependencies

Phase 0, Phase 1, Phase 10, Phase 9

## Backend Work

### Backend Work

1. **Stripe Configuration**
   - Environment variables: STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, STRIPE_PUBLISHABLE_KEY
   - Stripe account setup: products/prices for services, or ad-hoc amounts
   - Webhook endpoint: `/api/v1/webhooks/stripe`

2. **Payment Flow**
   - Submitter clicks "Pay Invoice" -> create Stripe Checkout Session or PaymentIntent
   - Amount from invoice total, currency from invoice
   - Metadata: invoice_id, package_id, submitter_id
   - Redirect to Stripe Checkout or confirm PaymentIntent
   - On success: Stripe redirects to success URL
   - Webhook confirms payment

3. **Webhook Handling**
   - Verify signature (STRIPE_WEBHOOK_SECRET)
   - Handle events: checkout.session.completed, payment_intent.succeeded, payment_intent.payment_failed, charge.refunded
   - Idempotency: process each event once (store event_id)
   - Replay protection: ignore duplicate event_ids
   - Update invoice status: `sent` -> `paid`
   - Update package status: `invoiced` -> `paid`
   - Record WinePackageEvent (type: `payment_received`)
   - Trigger payment confirmation notification (Phase 10)
   - Handle failures: invoice status -> `failed`, notify submitter

4. **Refund Handling**
   - Admin initiates refund via Stripe Dashboard or API
   - Webhook: charge.refunded -> update invoice status -> `refunded`
   - Package status adjustment if needed
   - Notification to submitter

5. **Security**
   - Never trust client-reported payment status
   - Webhook signature verification mandatory
   - Event idempotency enforced
   - No sensitive Stripe data in logs
   - PCI compliance: no card data touches our servers (Checkout handles it)

6. **Alternative Provider Decision**
   - If Stripe not selected: document chosen provider (Braintree, Adyen, GoCardless, manual bank transfer)
   - Same security requirements apply
   - Webhook/verification pattern adapted

## Frontend Work

### Frontend Work

1. **Payment Button**
   - In My Wine Packages invoice detail (Phase 7/11)
   - "Pay with Stripe" button
   - Disabled if invoice not in payable state
   - Loading state during redirect

2. **Payment Success/Cancel Pages**
   - Route: `/trade/payment/success?session_id=...`
   - Route: `/trade/payment/cancel`
   - Success: show confirmation, link to My Wine Packages
   - Cancel: show message, link back to invoice

3. **Stripe.js Integration**
   - Load Stripe.js with publishable key
   - Handle Checkout redirect or PaymentIntent confirmation

## Database and Migration Work

### Database and Migration Work

1. **Migrations**
   - Add `stripe_payment_intent_id`, `stripe_checkout_session_id`, `stripe_customer_id` to invoices
   - Add `paid_at`, `payment_method`, `payment_metadata` JSON
   - Create `stripe_webhook_events` table for idempotency (event_id, processed_at)
   - Index on event_id (unique)

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

- Webhook signature verification on every request
- Event idempotency (unique event_id constraint)
- No client-trusted payment status
- Stripe secret key only in backend
- Publishable key in frontend (VITE_STRIPE_PUBLISHABLE_KEY)
- PCI SAQ-A compliance (Checkout)
- Refunds only via Admin/Stripe Dashboard
- Payment metadata validated

## Testing Requirements

### Testing Requirements

1. **Webhook Tests**
   - Valid signature accepted
   - Invalid signature rejected
   - Duplicate event_id ignored
   - checkout.session.completed -> invoice paid
   - payment_intent.succeeded -> invoice paid
   - payment_intent.payment_failed -> invoice failed
   - charge.refunded -> invoice refunded
   - Package status updates to `paid`
   - Events recorded via WinePackageEvent.record!
   - Notifications triggered

2. **Integration Tests**
   - Full payment flow: invoice -> checkout -> webhook -> paid
   - Failure flow: checkout -> failed -> invoice failed
   - Refund flow
   - Idempotency on webhook retries

3. **Frontend Tests**
   - Pay button creates session/intent
   - Redirect to Stripe
   - Success/cancel pages work
   - Loading states

## Deployment/Configuration Requirements

### Deployment/Configuration Requirements

- Stripe account configured (test/live)
- Webhook endpoint registered in Stripe Dashboard
- Environment variables set in deployment
- SSL required for webhook endpoint
- Test mode vs live mode separation

## AI Implementation Prompt

```
Implement Stripe payment integration for Wine Words Trade portal invoices.

Requirements:
- Stripe Checkout or PaymentIntent for invoice payment
- Webhook endpoint with signature verification
- Event idempotency (unique event_id)
- Replay protection
- Payment status transitions: sent -> paid/failed/refunded
- Package status: invoiced -> paid
- Event recording via WinePackageEvent.record! and notifications
- Refund handling
- Security: no client-trusted status, PCI SAQ-A
- Alternative provider documented if Stripe not used

Key design points:
- Package status transitions: invoiced -> paid (on webhook confirmation)
- WinePackageEvent REUSED for payment_received event
- Invoice model extended with Stripe fields
- Webhook idempotency via unique event_id constraint
- Alternative provider decision documented if Stripe not selected

Deliver:
- Stripe service/checkout session creation
- Webhook controller with signature verification
- Event processing with idempotency
- Invoice/model extensions for Stripe fields
- Frontend payment button and success/cancel pages
- Stripe.js integration
- Request specs for webhook
- Integration tests for full payment flow
- Security tests (signature, idempotency, replay)
- Frontend tests
- Alternative provider decision document
```

## Acceptance Criteria

- [ ] Pay button creates Stripe Checkout/Intent
- [ ] Redirect to Stripe works
- [ ] Webhook verifies signature
- [ ] Valid event updates invoice to `paid`
- [ ] Duplicate event_id ignored
- [ ] Failed payment updates invoice to `failed`
- [ ] Refund updates invoice to `refunded`
- [ ] Package status updates to `paid`
- [ ] Events recorded via WinePackageEvent.record!
- [ ] Notifications triggered
- [ ] Success/cancel pages work
- [ ] No client-trusted payment status
- [ ] PCI SAQ-A compliant
- [ ] Alternative provider decision documented
- [ ] All tests pass

## Exit Gate

- Payment state derived from verified provider events
- Cannot be duplicated or forged
- Webhook idempotency and replay protection verified
- Integration with commercial workflow complete

## Implementation Notes

- Stripe Checkout recommended for simplest PCI compliance
- PaymentIntent + Elements if more control needed
- Test thoroughly in Stripe test mode before live
- Webhook endpoint must be publicly accessible HTTPS
- Consider Stripe Customer for repeat submitters
- Document alternative provider decision if Stripe not selected

## Validation Results

*To be completed during execution*

- Commands executed:
- Tests run:
- Failures:
- Unresolved issues:
