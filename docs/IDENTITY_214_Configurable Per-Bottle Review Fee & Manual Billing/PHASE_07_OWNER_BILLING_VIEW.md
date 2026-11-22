# IDENTITY_214 Phase 7 — Owner/Guest Read-Only Billing View

## Purpose
Give package owners visibility of the estimated and invoiced amounts on their
wine package page, without exposing staff-only billing actions.

## What was implemented

### Backend (already in place from Phases 4–5)
- `WinePackagePolicy#view_billing?` returns `show?` — package owners,
  submitters, creators, and editorial staff can all view billing.
- `WinePackagePolicy#manage_billing?` remains `editorial_manage?` (Admin/Editor
  only) — owners can never confirm billable counts, create invoices, mark paid,
  or cancel.
- `WinePackageSerializer#capabilities` emits both `manage_billing` and
  `view_billing` booleans.
- `GET /api/v1/wine_packages/:id/billing` returns the full billing summary
  (submitted, billable, invoiced, paid, outstanding, payment state, overdue,
  invoice history) to anyone who passes `view_billing?`.
- `GET /api/v1/invoices` (staff-wide index) remains `catalogue_manager?`-gated
  — not exposed to owners.

### Frontend (`WinePackageDetail.tsx`)
- The billing panel now has three visibility states:
  - `can.manage_billing` (Admin/Editor): full panel — confirm billable count,
    create invoices, download/email PDF, mark paid, cancel.
  - `can.view_billing && !can.manage_billing` (owner/guest): **read-only panel** —
    summary grid (submitted, billable, invoiced, paid, outstanding, payment
    state, overdue badge) + invoice cards (number, status, bottles, unit fee,
    total, issued/due dates, paid date, email history) + **Download PDF** only.
    All mutating actions (confirm billable, create invoice, email, mark paid,
    cancel) are hidden.
  - Neither: no billing section shown.
- Read-only enforcement is implemented in `WinePackageBillingPanel.tsx` via a
  `readOnly` prop that gates every mutating section/button. The backend policy
  is the authoritative guard; the frontend `readOnly` flag is a UX convenience
  only.

### What owners see (read-only)
- Bottles submitted (estimate snapshot)
- Billable bottles confirmed to date
- Total invoiced / total paid / outstanding balance
- Payment state badge (Not invoiced / Invoiced / Partially paid / Settled)
- Overdue badge when a sent invoice is past due
- Invoice list: number, status, bottles, unit fee, total, issued/due/paid dates,
  email sent timestamp + send count
- Download PDF for each invoice

### What owners do NOT see
- Confirm/Update billable count form
- Create invoice buttons
- Email invoice button
- Mark paid button
- Cancel invoice button
- Internal staff notes / attribution

### Payment instructions
Payment is handled externally (bank transfer per the invoice PDF). The read-only
panel shows the invoice PDF download link; the PDF itself contains the bank
transfer details. No payment gateway or "pay now" button is presented.

## Tests
- Backend: existing `wine_package_billing_spec` and `wine_package_invoices_spec`
  cover summary shape, invoice list, email tracking, PDF rendering, role-based
  access (403 for unauthorized roles).
- Frontend: `WinePackageDetail.test.tsx` (18 tests) and `Header.test.tsx` (24
  tests) pass; `tsc` reports 0 errors.

## Status: ✅ Completed
