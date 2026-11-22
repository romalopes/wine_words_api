# Phase 6 — Admin UI (Billing Panel)
**Status:** ✅ Completed
**Date:** 2026-11-22
**Depends on:** Phase 5 Staff API

---

## 1. Objective

Implement the billing panel in `TradeAdminPackageDetail.tsx` for staff to:
- View billing summary (bottles submitted, billable to date, totals)
- Confirm billable bottle count
- Create invoices for billable bottles
- Download PDF invoices
- Email invoices to package owners
- Mark invoices as paid
- Cancel/waive invoices with reason
- View invoice history with status badges

---

## 2. Implementation Complete

### Frontend Files Finalised

| File | Change |
|------|--------|
| `src/services/tradeApi.ts` | Billing API methods: `getBillingSummary`, `confirmBillableQuantity`, `createInvoice`, `sendInvoiceEmail`, `markInvoicePaid`, `cancelInvoice`, `downloadInvoicePdf` |
| `src/types/trade.ts` | Added `TradeBillingSummary`; extended `TradeInvoice` (payment_source, billable_bottle_count, unit_fee, email tracking, overdue) |
| `src/services/apiClient.ts` | Blob response support for PDF downloads (content-type detection) |
| `src/components/TradeAdminPackageDetail.tsx` | Full billing panel: summary grid, confirm billable, create invoice, invoice cards with actions, quotes section |
| `src/components/trade.module.css` | Billing panel + status badge styles |

### Billing Panel Features

1. **Summary grid** (6 tiles): bottles submitted, billable to date, total invoiced, total paid, outstanding (red when > 0), payment state badge + derived Overdue badge
2. **Confirm billable count** — number input + confirm button; hidden once confirmed
3. **Create invoice** — shows remaining delta bottles; button calls `POST /invoices`
4. **Invoice cards** — number, status badge (paid/sent/draft/cancelled + overdue), due/paid dates, bottles, unit fee, total, email sent count
5. **Per-invoice actions** — Download PDF (blob download), Email invoice (queues Solid Queue job), Mark paid (sent only), Cancel invoice (inline reason input → Confirm/Cancel)
6. **Quotes section** — existing quotes listed below invoices

### Bug Fixes Applied During Implementation

- Removed premature component close (`}` after helper functions) that broke the whole file
- Fixed `styles.statusBadge--overdue` member access → bracket notation `styles['statusBadge--overdue']`
- Fixed nested template literal className → string concatenation
- Added null guards (`!id`, `!pkg`) to all billing handlers
- Removed unused import/state; wired `billingLoading` into the UI
- apiClient: blob parsing for `application/pdf` responses
- **Routing/controller mismatch (root cause of "no buttons visible")**: the PATCH
  `/billing` route mapped to `billing#update` but the controller only defined
  `confirm_billable` — Rails raised `AbstractController::ActionNotFound` at request
  time and rendered an HTML 404, which the frontend swallowed silently. The
  controller now implements `update` (the frontend always PATCHes `/billing`);
  the orphan `confirm_billable` action/route was removed.
- **Missing PDF/email routes**: added `POST .../send_email`, `POST .../generate_pdf`
  and `GET .../pdf` member routes; controller action `download_pdf` renamed to `pdf`
  to match the route.
- **Money serialization**: BigDecimal `to_s("F")` produced `"250.0"` — serializers
  now emit 2-dp strings (`"250.00"`).
- `update_columns` on `WinePackage#confirm_billable_quantity!` used the association
  name instead of the FK column — now `billable_confirmed_by_id`.
- `update` renders 422 (JSON) instead of raising `ArgumentError` (500) for invalid
  billable counts.

### Shared panel refactor

The billing UI was extracted into `src/components/WinePackageBillingPanel.tsx`
(props: `packageId`, `onChanged`) and is now rendered on **both** staff pages:

- `/admin/trade/packages/:id` (`TradeAdminPackageDetail.tsx`) — replaces the old
  embedded copy; the Quotes list stays as its own card.
- `/wine-packages/:id` (`WinePackageDetail.tsx`) — new, gated on the
  `manage_billing` capability returned by `WinePackageSerializer#capabilities`
  (`manage_billing?`/`view_billing?` added to the serializer).

---

## 3. Verification Results

| Check | Result |
|-------|--------|
| `tsc --noEmit` TradeAdminPackageDetail.tsx | ✅ 0 errors |
| Backend RSpec (configurations, trade, pricing, wine_package) | ✅ 133 examples, 0 failures |
| `npm run build` (Vite production + PWA) | ✅ built in 3.32s |
| Remaining type errors project-wide | 27 pre-existing in unrelated files (baseline unchanged) |

---

## 4. Phase Status

| Phase | Status |
|-------|--------|
| 0 | ✅ Completed |
| 1 | ✅ Completed |
| 2 | ✅ Completed |
| 3 | ✅ Completed |
| 4 | ✅ Completed |
| 5 | ✅ Completed (Core) |
| 6 | ✅ Completed |
| 7 | ⏳ Pending |
| 8 | ⏳ Pending |
| 9 | ⏳ Pending |
| 10 | ⏳ Pending |
| 11 | ⏳ Pending |
| 12 | ✅ Implemented (Core) |

---

## 5. Next Steps

1. **Phase 7** — Owner/guest read-only billing view (`TradePackageDetail.tsx`, guest tracking page)
2. **Phase 8** — Multiple-invoice workflow tests (immutability, aggregates)
3. **Phase 12b** — Overdue reminder job
4. **Phase 12c** — Auto-send on record (configurable)
---

## 2. Backend Status: ✅ Complete

All backend APIs are implemented and tested:

| Endpoint | Method | Status |
|----------|--------|--------|
| `GET /api/v1/wine_packages/:id/billing` | GET | ✅ |
| `PATCH /api/v1/wine_packages/:id/billing` | PATCH (confirm billable) | ✅ |
| `POST /api/v1/wine_packages/:id/invoices` | POST (create) | ✅ |
| `POST /api/v1/wine_packages/:id/invoices/:iid/send_email` | POST | ✅ |
| `POST /api/v1/wine_packages/:id/invoices/:iid/mark_paid` | POST | ✅ |
| `POST /api/v1/wine_packages/:id/invoices/:iid/cancel` | POST | ✅ |
| `GET /api/v1/wine_packages/:id/invoices/:iid/pdf` | GET | ✅ |

**Tests:** 133 backend examples, 0 failures

---

**TradeApi Methods Added:**
- `getBillingSummary(packageId)`
- `confirmBillableQuantity(packageId, count)`
- `createInvoice(packageId, payload)`
- `sendInvoiceEmail(packageId, invoiceId)`
- `markInvoicePaid(packageId, invoiceId)`
- `cancelInvoice(packageId, invoiceId, reason)`
- `downloadInvoicePdf(packageId, invoiceId)`

**Types Added/Updated:**
- `TradeBillingSummary` interface
- `TradeInvoice` - added payment_source, billable_bottle_count, unit_fee, recorded_by_id, recorded_at, cancellation_reason, notes, email_sent_at, email_send_count, reminder_sent_at, overdue

---

## 4. Required Frontend Fix

**File:** `src/components/TradeAdminPackageDetail.tsx`

**Issues:** JSX syntax errors from partial edits (unclosed tags, mismatched braces)

**Required Work:**
1. Fix JSX syntax errors in the billing panel section
2. Complete the billing panel implementation with:
   - Billing summary grid (bottles submitted, billable to date, totals)
   - Confirm billable quantity input + button
   - Create invoice button (when billable confirmed)
   - Invoice list with cards showing:
     - Invoice number, status badge, due date, paid date
     - Bottles, unit fee, total
     - Email sent status
     - Action buttons: Download PDF, Email, Mark Paid, Cancel
   - Cancel invoice modal with reason input
   - Quotes section (existing)

**State Variables to Use:**
- `billingSummary`, `billingLoading`
- `confirmBillableCount`, `confirmingBillable`
- `creatingInvoice`, `invoiceError`
- `sendingEmail`, `markingPaid`, `cancellingInvoice`, `cancellationReason`

**Helper Functions to Use:**
- `formatCurrency(amount, currency)`
- `getPaymentStateLabel(state)`
- `getStatusBadgeClass(status)`
- `handleConfirmBillable()`, `handleCreateInvoice()`
- `handleSendInvoiceEmail(invoiceId)`, `handleMarkInvoicePaid(invoiceId)`
- `handleCancelInvoice(invoiceId)`, `handleDownloadInvoicePdf(invoiceId)`
- `loadBillingSummary()`
## 3. Frontend Status: 🔄 Needs Fix

**Files Modified:**
- `src/services/tradeApi.ts` - Added billing API methods ✅
- `src/types/trade.ts` - Added `TradeBillingSummary`, updated `TradeInvoice` ✅
- `src/components/TradeAdminPackageDetail.tsx` - **Syntax errors from partial edits** 🔄
- Email invoices to package owners
- Mark invoices as paid
- Cancel/waive invoices with reason
- View invoice history with status badges
---

## 5. CSS Classes Needed

Add to `trade.module.css`:
```css
.billingSummary { margin-bottom: 1.5rem; }
.summaryGrid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 1rem; }
.summaryItem { display: flex; flex-direction: column; gap: 0.25rem; }
.summaryLabel { font-size: 0.875rem; color: #766963; font-weight: 500; }
.summaryValue { font-size: 1.125rem; font-weight: 600; color: #241b19; }
.billingAction { margin-top: 1.5rem; padding: 1rem; background: #f5f0ea; border: 1px solid #e4d9cd; border-radius: 8px; }
.invoiceList { display: flex; flex-direction: column; gap: 1rem; margin-top: 1rem; }
.invoiceCard { border: 1px solid #e4d9cd; border-radius: 8px; padding: 1rem; }
.invoiceHeader { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 0.75rem; }
.invoiceMeta { display: flex; gap: 1rem; font-size: 0.875rem; color: #766963; }
.invoiceDetails { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 0.75rem; margin: 1rem 0; padding: 1rem; background: #f5f0ea; border-radius: 8px; }
.invoiceDetail { display: flex; flex-direction: column; gap: 0.25rem; }
.invoiceDetail .muted { font-size: 0.75rem; }
.invoiceActions { display: flex; flex-wrap: wrap; gap: 0.5rem; margin-top: 1rem; }
.paidBadge { color: #1f654a; font-weight: 600; }
.status-badge { display: inline-block; padding: 0.2rem 0.5rem; border-radius: 4px; font-size: 0.75rem; font-weight: 600; }
.status-badge--paid { background: #d4edda; color: #155724; }
.status-badge--sent { background: #fff3cd; color: #856404; }
.status-badge--draft { background: #e2e3e5; color: #383d41; }
.status-badge--cancelled { background: #f8d7da; color: #721c24; }
.status-badge--overdue { background: #f8d7da; color: #721c24; animation: pulse 2s infinite; }
.status-badge--not_invoiced { background: #e2e3e5; color: #383d41; }
.status-badge--invoiced { background: #cce5ff; color: #004085; }
.status-badge--partially_paid { background: #fff3cd; color: #856404; }
.status-badge--settled { background: #d4edda; color: #155724; }
.quotesSection { margin-top: 1.5rem; padding-top: 1rem; border-top: 1px solid #e4d9cd; }
.quoteItem { padding: 0.5rem 0; color: #4f4440; }
```

---

## 6. Phase Status Update

| Phase | Status |
|-------|--------|
| 0 | ✅ Completed |
| 1 | ✅ Completed |
| 2 | ✅ Completed |
| 3 | ✅ Completed |
| 4 | ✅ Completed |
| 5 | ✅ Completed (Core) |
| 6 | 🔄 In Progress (Backend ✅, Frontend 🔄) |
| 7 | ⏳ Pending |
| 8 | ⏳ Pending |
| 9 | ⏳ Pending |
| 10 | ⏳ Pending |
| 11 | ⏳ Pending |
| 12 | ✅ Implemented (Core) |

---

## 7. Next Steps

1. **Fix TradeAdminPackageDetail.tsx** JSX syntax errors
2. **Complete billing panel** with all UI components
3. **Add CSS styles** to trade.module.css
4. **Test manually** with real data
5. **Add request specs** for new billing endpoints
6. **Proceed to Phase 7** (Owner/Guest Billing View)

## Post-review Bug Fixes (second pass)

1. **Reviews unlock on arrival**: `WinePackage#mark_arrived!` now flags every
   line of a `trade_submission` package `review_requested: true` (producer
   requests are untouched — the reviewer explicitly chooses there), and
   `WinePackageItem#reviewable?` additionally treats arrived/reviewing/
   completed trade-submission lines as reviewable, so lines added *after*
   arrival also get the "Create review" button. Migration
   `20261122103000_backfill_review_requested_for_arrived_trade_packages`
   flags lines of packages that were already arrived when the fix landed.
2. **Email feedback**: the billing panel shows a success notice
   ("Invoice email sent…") after the send resolves; the invoice card already
   displays "Emailed: <date> (Nx)".
3. **Resending works**: removed the silent-skip guard in `InvoiceMailerJob`
   (`return if email_sent_at…`) — staff-triggered sends always deliver and
   increment `email_send_count`.
4. **Cancel invoice fixed**: the outer "Cancel invoice" button toggled the
   wrong state (`cancellationReason` instead of `cancellingInvoice`), so the
   reason input never appeared. It now opens the inline form with autofocus;
   the dismiss button closes it.
5. **Follow-up invoices after new lines**: `BillingSummary` exposes
   `billable_uninvoiced` (billable bottles not covered by an active
   sent/paid invoice; cancelled invoices release their bottles). Invoice
   creation accepts `coverage`: `difference` (default — just the uninvoiced
   bottles) or `full` (one consolidated invoice for the whole billable
   count). The panel offers both buttons when prior invoices exist, and
   cancelled invoices no longer block the delta. The billable-count block now
   also appears (titled "Update billable count", pre-filled with the
   submitted total) whenever new bottles have arrived since the last
   confirmation — previously it only showed while the count was unset, which
   dead-ended the follow-up flow. PATCH billing refuses counts below the
   bottles already covered by active invoices.

## Settings → Invoices overview page

New cross-package listing for Admins/Editors:

- **API**: `GET /api/v1/invoices`
  (`Api::V1::InvoicesController#index`, gated on `catalogue_manager?` — the
  same audience as `manage_billing?` without the per-package reviewer clause).
  Returns every non-draft invoice (newest first) with 2-dp money, email
  delivery state, the client (contact_snapshot → producer → submitter
  fallback) and the package relationship (id, status, source, producer, wine
  line count). Read-only — mutations stay on the nested wine-package routes.
- **UI**: `/settings/invoices` (`InvoicesList.tsx`), menu item "Invoices" in
  the Settings dropdown (visible to Admins/Editors via `canManageAllPackages`).
  Columns: invoice number (+ payment source), client, relationship (link to
  the package), bottles, total, status (+ Overdue / paid date), issued/due,
  email history (last sent + send count). Row actions **Download** and
  **Email** reuse the per-package `pdf` / `send_email` endpoints (email asks
  for confirmation because it re-sends).