# Phase 4 — Database Migrations and Invoice Model
**Status:** ✅ Completed
**Date:** 2026-11-22
**Depends on:** Phase 3 Submission Estimate

---

## 1. Objective

Implement the approved billing persistence model:
- Package-level historical estimate snapshot
- Extended `wine_package_invoices` table with manual-billing fields
- Model validations, scopes, and status transitions
- `WinePackages::BillingSummary` aggregate service
- Safe migration with no backfill of legacy data

---

## 2. Migration

**File:** `db/migrate/20261122033506_add_review_fee_billing_to_wine_packages_and_invoices.rb`

### `wine_packages` — New Columns (all nullable)

| Column | Type | Purpose |
|--------|------|---------|
| `estimated_bottle_count` | integer | Submitted bottle count at snapshot time |
| `estimated_unit_fee` | decimal(10,2) | Fee per bottle at submission |
| `estimated_currency` | string(8) | Currency code (AUD) |
| `estimated_total` | decimal(10,2) | Estimated total (fee × count) |
| `estimate_snapshot_at` | datetime | When snapshot was captured |
| `billable_bottle_count` | integer | Staff-confirmed billable count |
| `billable_confirmed_by_id` | bigint (FK→users) | Staff member who confirmed |
| `billable_confirmed_at` | datetime | When count was confirmed |

### `wine_package_invoices` — New Columns

| Column | Type | Purpose |
|--------|------|---------|
| `payment_source` | string(16) | `stripe` (legacy) or `manual` (new) |
| `billable_bottle_count` | integer | Bottles this invoice covers |
| `unit_fee` | decimal(10,2) | Fee per bottle snapshot |
| `recorded_by_id` | bigint (FK→users) | Staff who recorded |
| `recorded_at` | datetime | When recorded |
| `cancellation_reason` | string(255) | Required if cancelled |
| `notes` | text | Staff-only notes |

### Indexes & Backfill
- Index on `payment_source` and `recorded_by_id`
- Existing invoices backfilled with `payment_source = 'stripe'`

---

## 3. Model Changes

### WinePackageInvoice (`app/models/wine_package_invoice.rb`)

**New Associations:**
- `belongs_to :recorded_by, class_name: "User"`

**New Enums:**
- `payment_source: { stripe: 0, manual: 1 }` (default: stripe)

**New Validations:**
- `billable_bottle_count` required & >0 for manual
- `unit_fee` required & ≥0 for manual
- `recorded_by` & `recorded_at` required when manual & sent
- `cancellation_reason` required when cancelled
- `immutable_money_fields_once_sent` — prevents modification of money fields after `sent`
- `stripe_invoice_requires_quote` — Stripe invoices must have a quote

**New Scopes:**
- `.manual` / `.stripe`

**New Methods:**
- `manual?` / `stripe?`
- `sent?` / `paid?`
- `overdue_for_display?` — derived overdue (never sets stored enum)
- `immutable_money_fields_once_sent` — validation
- `payment_gate_satisfied?` — unchanged

### WinePackage (`app/models/wine_package.rb`)

**New Association:**
- `belongs_to :billable_confirmed_by, class_name: "User"`

**New Methods:**
- `submitted_bottle_count` — Σ `wine_package_items.quantity`
- `capture_estimate!(fee_amount, fee_currency)` — immutable snapshot at submission
- `confirm_billable_quantity!(count, by:)` — staff confirmation
- `estimate_captured?` / `billable_confirmed?`

---

## 4. BillingSummary Service

**File:** `app/services/wine_packages/billing_summary.rb`

**Aggregates (manual invoices only):**
- `bottles_submitted` — from estimate snapshot or live count
- `billable_to_date` — package `billable_bottle_count`
- `total_invoiced` — Σ manual invoice totals (non-draft)
- `total_paid` — Σ paid invoice totals
- `total_cancelled` — Σ cancelled invoice totals
- `outstanding` — Σ sent invoice totals
- `payment_state` — `:not_invoiced` / `:invoiced` / `:partially_paid` / `:settled`
- `overdue?` — any sent invoice with `due_at < now`

**Invoice History:** Each manual invoice serialized with full details including derived `overdue` flag.

---

## 5. Migration/Backfill Policy

| Data | Treatment |
|------|-----------|
| Pre-feature `wine_packages` | New columns NULL; UI shows "Not priced under current billing workflow" |
| Pre-feature `wine_package_invoices` | `payment_source` = "stripe"; no other changes |
| No fee backfill | Legacy packages never get AUD 50 retroactively |

**Reversible:** All columns drop cleanly.

---

## 6. Tests

| Test Suite | Result |
|------------|--------|
| `spec/models/wine_package_spec.rb` | ✅ 72 examples, 0 failures |
| `spec/requests/api/v1/configurations_spec.rb` | ✅ 20 examples, 0 failures |
| `spec/requests/api/v1/trade_spec.rb` | ✅ 34 examples, 0 failures |
| `spec/requests/api/v1/trade/pricing_spec.rb` | ✅ 2 examples, 0 failures |

All 56 related tests pass.

---

## 7. Files Changed

| File | Change Type |
|------|-------------|
| `db/migrate/20261122033506_add_review_fee_billing_to_wine_packages_and_invoices.rb` | New migration |
| `app/models/wine_package_invoice.rb` | Added manual billing fields, validations, scopes, methods |
| `app/models/wine_package.rb` | Added billing associations, snapshot/capture methods |
| `app/services/wine_packages/billing_summary.rb` | New aggregate service |

---

## 8. Phase Status Update

| Phase | Status |
|-------|--------|
| 0 | ✅ Completed |
| 1 | ✅ Completed |
| 2 | ✅ Completed |
| 3 | ✅ Completed |
| 4 | ✅ Completed |
| 5 | ⏳ Pending |
| 6 | ⏳ Pending |
| 7 | ⏳ Pending |
| 8 | ⏳ Pending |
| 9 | ⏳ Pending |
| 10 | ⏳ Pending |
| 11 | ⏳ Pending |

---

*Next: Phase 5 — Staff Billing Workflow and API*