# Phase 1 — Domain Model & Business Rules
**Status:** ✅ Completed
**Date:** 2026-11-22
**Depends on:** Phase 0 Audit

---

## 1. Core Concepts

### 1.1 Bottle Count Definitions

| Term | Definition | Source |
|------|------------|--------|
| **Submitted Bottle Count** | Σ `wine_package_items.quantity` for all items on the package at submission time | Computed server-side |
| **Estimated Billable Count** | Same as submitted count (shown to user pre-submission) | Snapshot at submission |
| **Confirmed Billable Count** | Staff-confirmed integer; pre-filled from review-requested items; may be adjusted | `wine_packages.billable_bottle_count` |
| **Invoiced Delta** | Per-invoice `billable_bottle_count` — the incremental count this invoice covers | `wine_package_invoices.billable_bottle_count` |

### 1.2 Fee & Currency Snapshots

| Level | Fields | When Captured |
|-------|--------|---------------|
| **Package (submission estimate)** | `estimated_unit_fee`, `estimated_currency`, `estimated_bottle_count`, `estimated_total`, `estimate_snapshot_at` | At submission (both trade & producer paths) |
| **Invoice** | `unit_fee`, `currency`, `billable_bottle_count`, `subtotal`, `tax`, `total` | At invoice creation (manual recording) |

**Rule:** Once captured, these values are **immutable**. Later global fee changes do not affect historical records.
---

## 2. Invoice Lifecycle

### 2.1 Status Enum (reuses existing)

```
draft → sent → paid
           → cancelled (with cancellation_reason)
```

- `draft` — created but not yet recorded as sent (optional, for staff convenience)
- `sent` — staff has externally sent the invoice; requires `invoice_number`, `issued_at`, `due_at`
- `paid` — payment confirmed; requires `paid_at`
- `cancelled` — voided/waived; requires `cancellation_reason` (e.g., "waived", "duplicate", "error")

**No new status values added.** `overdue` remains in enum for legacy Stripe path only; manual invoices never set it.

### 2.2 Valid Transitions

| From | To | Required Fields | Trigger |
|------|-----|-----------------|---------|
| draft | sent | `invoice_number`, `issued_at`, `due_at` | "Record invoice sent" |
| draft | cancelled | `cancellation_reason` | "Cancel draft" |
| sent | paid | `paid_at` | "Mark paid" |
| sent | cancelled | `cancellation_reason` | "Waive/Cancel" |
| paid | (none) | — | Immutable once paid |
| cancelled | (none) | — | Immutable |

---

## 3. One Package → Many Invoices

### 3.1 First Invoice
- Covers the initial `billable_bottle_count` confirmed by staff
- Snapshots `unit_fee` = current global fee at that moment
- Creates `WinePackageEvent` `invoice_recorded`

### 3.2 Additional Bottles → New Invoice
- Staff increases package `billable_bottle_count`
- System computes **delta** = new count − sum of prior invoices' `billable_bottle_count`
- New invoice created for delta only, with current `unit_fee` snapshot
- **Prior invoices immutable** — amounts, numbers, dates, statuses never change
### 3.3 Aggregate Calculations (WinePackages::BillingSummary)

```ruby
# All scoped to a single wine_package
total_invoiced   = invoices.where.not(status: "draft").sum(:total)
total_paid       = invoices.where(status: "paid").sum(:total)
total_cancelled  = invoices.where(status: "cancelled").sum(:total)
outstanding      = invoices.where(status: "sent").sum(:total)
overdue_flag     = invoices.where(status: "sent").where("due_at < ?", Date.current).exists?
payment_state    = case
                   when invoices.where(status: "sent").none? then "not_invoiced"
                   when outstanding.zero?                   then "settled"
                   else                                        "partially_paid"
                   end
```

**Exclusion rules:**
- `draft` invoices excluded from all aggregates
- `cancelled` invoices excluded from `outstanding` and `payment_state` logic
- No partial payments, no ledger

---

## 4. Snapshot Semantics

| Scenario | Estimate Snapshot | Billable Count | Invoice Snapshot |
|----------|-------------------|----------------|------------------|
| New trade submission | ✅ at create | NULL until staff confirms | — |
| Producer request submit | ✅ at submit | NULL until staff confirms | — |
| Staff confirms billable count | — | ✅ package field | — |
| Staff records invoice | — | — | ✅ per-invoice (count, fee, currency, total) |
| Global fee changed | ❌ no effect | — | ❌ no effect on existing |
| Additional bottles accepted | — | ✅ updated | ✅ new invoice for delta |

**Legacy packages (pre-billing feature):** All snapshot fields NULL → UI shows "Not priced under current billing workflow". No backfill.

---

## 5. Rounding & Precision

- All monetary values: `decimal(10,2)` columns, `BigDecimal` in Ruby
- Calculation: `total = (unit_fee × billable_bottle_count) + tax`
- Tax default 0, staff-editable per invoice
- Rounding: half-up to 2 decimal places (Ruby `BigDecimal#round(2)`)
- Currency: ISO 4217 3-letter code (validated against known list)

---

## 6. Authorization Matrix

| Action | Admin/Editor (catalogue_manager?) | Reviewer (assigned) | Producer Owner/Manager | Package Owner (guest/submitter) | Public |
|--------|-----------------------------------|---------------------|------------------------|--------------------------------|--------|
| Read global fee | ✅ | ✅ | ✅ | ✅ | ✅ |
| Update global fee | ✅ | ❌ | ❌ | ❌ | ❌ |
| Read package billing summary | ✅ | ✅ | ✅ | ✅ (own) | ❌ |
| Confirm billable count | ✅ | ❌ | ❌ | ❌ | ❌ |
| Record invoice (sent) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Mark invoice paid | ✅ | ❌ | ❌ | ❌ | ❌ |
| Cancel/waive invoice | ✅ | ❌ | ❌ | ❌ | ❌ |
| View staff notes / audit | ✅ | ❌ | ❌ | ❌ | ❌ |

**Policy methods to add to `WinePackagePolicy`:**
```ruby
def manage_billing? = editorial_manage?  # catalogue_manager? || reviewer
def view_billing?   = show?              # same as show? (owner + editorial)
```

---

## 7. Derived Package Payment State (Not Stored)

| Computed State | Condition |
|----------------|-----------|
| `not_invoiced` | No non-draft invoices exist |
| `invoiced` | ≥1 `sent` invoice, none paid |
| `partially_paid` | ≥1 `sent` invoice, some `paid`, some `sent` |
| `settled` | All non-draft invoices are `paid` |
| `overdue` (display) | Any `sent` invoice with `due_at < Date.current` |

This is **not** a column on `wine_packages` — computed by `WinePackages::BillingSummary`.

---

## 8. Events / Audit Trail

Every billing mutation emits a `WinePackageEvent` (shared visibility unless noted):

| Event Type | Actor | Metadata |
|------------|-------|----------|
| `estimate_captured` | system (submission) | `{ estimated_bottle_count, estimated_unit_fee, estimated_currency, estimated_total }` |
| `billable_quantity_confirmed` | staff | `{ previous_count, new_count, confirmed_by_id }` |
| `invoice_recorded` | staff | `{ invoice_id, invoice_number, billable_bottle_count, unit_fee, total, payment_source: "manual" }` |
| `invoice_marked_paid` | staff | `{ invoice_id, paid_at }` |
| `invoice_cancelled` | staff | `{ invoice_id, cancellation_reason }` |
| `global_fee_changed` | admin | `{ previous_amount, new_amount, currency }` (via `Auditable` on `AppSetting`) |

---

## 9. Migration/Backfill Policy

| Existing Data | Treatment |
|---------------|-----------|
| `wine_packages` pre-feature | New columns NULL; UI shows legacy message |
| `wine_package_invoices` (Stripe) | `payment_source` backfilled to `"stripe"`; no other changes |
| `app_settings` | New keys added with defaults; no migration needed |

**All migrations reversible** — columns drop cleanly.

---

## 10. Deliverables This Phase

- ✅ This domain model document (`PHASE_01_DOMAIN_MODEL.md`)
- ✅ Formal rules for counts, statuses, snapshots, aggregates, rounding, authorization, events
- ✅ Migration/backfill policy
- ⏳ Original plan `.md` §0 amendments (next)
- ⏳ Phase 2 implementation (configurable pricing)

---

*No implementation changes in this phase. Phase 2 begins implementation.*