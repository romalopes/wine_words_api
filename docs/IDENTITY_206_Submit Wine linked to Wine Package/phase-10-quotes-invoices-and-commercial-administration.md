# Phase 10 — Quotes, Invoices, and Commercial Administration

## Status

Partially implemented on November 14, 2026.

## Objective

Implement commercial workflow: service/pricing configuration, quote generation, invoice generation, invoice documents, tax/currency handling, commercial status transitions, and duplicate prevention.

## Dependencies

Phase 0, Phase 1, Phase 3, Phase 6, Phase 7, Phase 9

## Backend Work

### Backend Work

1. **Pricing Configuration**
   - Service definitions: review, listing, review+listing
   - Price per service (Admin-configurable)
   - Currency support (base currency + display currencies)
   - Tax rules (VAT/GST by submitter country — read from the JSONB `contact_snapshot.country`)

2. **Quote Model (NEW table)**
   - `WinePackageQuote`: `wine_package_id`, `service_type`, `items[]`, `subtotal`, `tax`, `total`, `currency`, `status` (draft, sent, accepted, expired, cancelled), `valid_until`, `created_by_id`
   - One active quote per package per service batch; Editor creates after assessment (Phase 7)

3. **Invoice Model (NEW table)**
   - `WinePackageInvoice`: `wine_package_id`, `quote_id`, `invoice_number` (unique, sequential), `items[]`, `subtotal`, `tax`, `total`, `currency`, `status` (draft, sent, paid, overdue, cancelled), `issued_at`, `due_at`, `paid_at`, PDF attachment (ActiveStorage, private)
   - Generated from an accepted quote; numbering sequence initialised at DB level

4. **Endpoints**
   - `GET/POST/PATCH /api/v1/admin/trade/packages/:id/quote` — view/create/update (draft only)
   - `POST /api/v1/admin/trade/packages/:id/quote/accept` — accept quote → generate invoice
   - `GET /api/v1/trade/my-packages/:id/invoices` and `.../invoices/:invoice_id` — submitter view + PDF
   - `POST /api/v1/admin/trade/packages/:id/invoices` — manual invoice (Admin)

5. **Commercial status transitions**
   - Package: `approved` → `quoted` → `invoiced` → `paid`
   - Quote: draft → sent → accepted/expired/cancelled
   - Invoice: draft → sent → paid/overdue/cancelled
   - Every transition → `WinePackageEvent.record!` (types: `quote_created`, `quote_accepted`, `invoice_created`)

6. **Duplicate prevention**
   - One active quote per package per service; one invoice per accepted quote
   - Idempotency on invoice generation (align with event idempotency keys)

7. **Invoice PDF generation**
   - Prawn (pure Ruby) or Grover (Puppeteer); stored in private ActiveStorage; signed download URL

8. **Authorization**
   - Editor/Admin: create/update quotes, generate invoices
   - Submitter: view own quotes/invoices, accept quote
   - Guest token: view quotes/invoices for its single package

## Frontend Work

### Frontend Work

1. **Admin Quote Management** — `/admin/trade/packages/:id/quote`
   - Service selection, per-item pricing, tax calculation preview, draft save, send to submitter, PDF preview

2. **Admin Invoice Management** — `/admin/trade/packages/:id/invoices`
   - Invoice list, generate-from-quote, manual create, PDF download, status tracking

3. **Submitter View** — inside My Wine Packages (Phase 6) Commercial tab
   - Quote status + accept button, invoice list with status, PDF download, payment CTA (Phase 11)

4. **Mobile** — quote form usable on mobile; invoice list as cards

## Database and Migration Work

### Database and Migration Work

1. **Migrations**
   - Create `wine_package_quotes` and `wine_package_invoices` tables
   - Invoice-number sequence (or UUID strategy) with a unique DB index
   - ActiveStorage attachment for invoice PDFs
   - Indexes: `wine_package_id`, `status`, unique `invoice_number`; foreign keys

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

- Invoice PDFs stored privately; signed download URLs with expiry
- Submitter sees only own quotes/invoices; guest token scoped to its package
- Quote/invoice amounts not modifiable by submitter
- Unique invoice numbering enforced at DB level; no duplicate invoice per quote
- Admin authorization required for quote/invoice creation and mutation

## Testing Requirements

### Testing Requirements

1. **Request Tests**
   - Quote creation from pricing config; tax calculation from `contact_snapshot.country`
   - Quote acceptance generates exactly one invoice (idempotent)
   - Invoice PDF generated, stored privately, downloadable via signed URL
   - Unique sequential invoice numbering; duplicate prevention
   - Status transitions for package/quote/invoice
   - Submitter and guest-token view authorization

2. **Frontend Tests**
   - Quote form calculation; invoice list statuses; PDF download; mobile layout

3. **Financial Tests**
   - Rounding correct; tax per jurisdiction; invoice totals equal quote totals

## Deployment/Configuration Requirements

### Deployment/Configuration Requirements

- Pricing configuration source (Admin UI or env/secrets)
- Invoice-number sequence initialisation
- PDF library dependency (Prawn recommended — pure Ruby, no external process)
- ActiveStorage private bucket for invoices

## AI Implementation Prompt

```
Implement quotes, invoices, and commercial administration for the Wine Words Trade portal.

Requirements:
- Service/pricing configuration (review, listing, both)
- Quote creation by Editor after assessment (Phase 7); acceptance generates invoice
- Unique sequential invoice numbers (DB-enforced)
- PDF invoice generation (Prawn or Grover) stored in PRIVATE ActiveStorage, signed download
- Tax calculation per submitter country — read from the JSONB contact_snapshot.country
- Commercial status transitions: approved -> quoted -> invoiced -> paid
- Duplicate prevention: one active quote per package/service, one invoice per accepted quote,
  idempotent invoice generation
- Submitter view/accept/download; guest token read-only for its package
- Admin management UI

Deduplication constraints (from Phase 1):
- Package status transitions reuse the extended WinePackage status enum (quoted, invoiced, paid)
- Record lifecycle events via WinePackageEvent.record! (quote_created, quote_accepted,
  invoice_created) — no separate audit log
- Only new tables: wine_package_quotes, wine_package_invoices
- Payment execution is Phase 11 (Stripe) — this phase must NOT allow payment before an invoice exists

Deliver:
- Quote and Invoice models with validations and status guards
- API endpoints (admin CRUD, submitter read/accept)
- Pricing configuration and tax calculation service (reads contact_snapshot)
- Invoice PDF generation and numbering
- Frontend admin quote/invoice pages and submitter Commercial tab integration
- Request specs, financial calculation tests, authorization tests, frontend tests
```

## Acceptance Criteria

- [ ] Editor can create a quote for approved items
- [ ] Pricing configuration used correctly; tax from `contact_snapshot.country`
- [ ] Quote acceptance generates exactly one invoice
- [ ] Invoice PDF generated, stored privately, downloadable
- [ ] Unique sequential invoice numbers; duplicates impossible
- [ ] Status transitions: quoted → invoiced → paid
- [ ] Submitter can view/accept quote and download invoices
- [ ] Guest token can view quotes/invoices for its package
- [ ] Admin can manage quotes/invoices
- [ ] Financial calculations correct (rounding, tax)
- [ ] All tests pass

## Exit Gate

- Approved packages receive accurate, auditable commercial documents
- Invoice generation integrated with the assessment workflow (Phase 7 trigger)
- Financial calculations tested; authorization boundaries enforced
- Payment deferred to Phase 11 — no payment before invoice exists

## Implementation Notes

- Reuse existing Wine Words billing patterns where present
- Prawn recommended for PDF (pure Ruby; Grover requires Puppeteer/Chromium)
- Tax rules likely need per-country configuration
- Store base currency; display conversion optional
- Invoice totals must always equal the accepted quote totals

## Validation Results

- Commands executed: `cd /Users/romalopes/Documents/studies/my_project/wine_project/wine_words && npm run build`; `cd /Users/romalopes/Documents/studies/my_project/wine_project/wine_words_api && bundle exec rspec spec/requests/api/v1/trade_spec.rb`
- Result: frontend build passed; backend Trade request scenarios have been exercised.
- Implemented: submitter/guest commercial summary, invoice status display, and Stripe Checkout CTA from the package detail page.
- Not implemented: admin quote/invoice pages, submitter quote acceptance UI, invoice PDF download UI, pricing configuration UI, and invoice document attachments.
- Unresolved issues: payment status remains webhook-authoritative; the frontend must not display an invoice as paid solely because the user returned from Stripe. Backend request fixtures currently fail quote item validation because their item data lacks `unit_price`; this must be resolved before treating the commercial workflow as verified.
