# Phase 0 — Architecture Audit & Reconnaissance
**Status:** ✅ Completed
**Date:** 2026-11-22
**Branch:** main (both repos clean)

---

## 1. Repositories

| Repo | Local Path | Stack |
|------|------------|-------|
| Backend API | `wine_words_api/` | Rails 8.1, PostgreSQL, RSpec 7, Pundit, Devise+JWT, Stripe, Solid Queue, Sentry |
| Frontend | `wine_words/` | React 19 + Vite + TypeScript, HeroUI, react-router 7, Vitest + Playwright, Capacitor |

*Note: The original plan references `wine_words_frontend` — actual folder is `wine_words/`.*

---

## 2. Existing Structures Relevant to Billing

| Structure | Key Details |
|-----------|-------------|
| **WinePackage** | Single `status` enum mixing submission + payment workflow: `draft → requested → announced → in_transit → arrived → reviewing → completed → cancelled → editorial_pending → assessment_in_progress → partially_approved → approved → quoted → invoiced → paid → shipping_pending → shipping_released`. Trade chain transitions in `TRADE_TRANSITIONS`. `overdue?` derived from review deadline only. |
| **WinePackageItem** | `quantity` (integer > 0), `review_requested` boolean, snapshot_* immutable fields. Bottle count = Σ `quantity`. |
| **WinePackageInvoice** | **Already exists** (migration `20261114000004`): `invoice_number` `WW-YYYY-####` (unique per-year seq), `currency` default **EUR**, `items` JSONB, `subtotal/tax/total` decimal(10,2), status enum `draft/sent/paid/overdue/cancelled/refunded` (**`overdue` is a stored enum value**), `issued_at/due_at/paid_at`, Stripe fields (`stripe_checkout_session_id`, `stripe_payment_intent_id`, `stripe_payment_metadata`). Generated ONLY from accepted quote via `Trade::Invoices::GenerateFromQuote`. Payment mutated ONLY by Stripe webhook. |
| **WinePackageQuote** | Service types: `review/listing/review_and_listing`. Frozen items JSONB. One active quote per package per service. Default currency EUR. |
| **AppSetting** | Key/value store with typed accessors, `DEFAULTS` hash, `RESERVED_KEYS`, admin Configuration page (`Api::V1::ConfigurationsController`). StatementInvalid fallbacks for boot-time safety. Perfect home for configurable fee. |
| **WinePackageEvent** | Audit timeline: `event_type`, `actor` (User), `visibility` (`shared`/`internal`), `metadata` JSONB. Used for `trade_submitted`, `invoice_created`, etc. |
| **WinePackagePolicy** | Four tiers: `catalogue_manager?` (Admin/Editor), reviewer (assigned), producer owner/manager (active membership), others. Scoped `create?`, `update?`, `manage?`, `manage_items?`, `manage_attachments?`, `manage_tracking?`, `submit?`, `withdraw?`, `accept?`, `reject?`, etc. |
| **Billing namespace** | **Occupied** by user-subscription Stripe billing: `BillingController`, `Billing::ReconcileSubscriptionsJob`, `BillingEvent`, `BillingCustomer`, `SubscriptionBillingPrice`. |
| **Two submission paths** | 1. Public anonymous trade submissions (guest token, Turnstile, entry status `editorial_pending`) via `TradeSubmit.tsx` + `Trade::Submissions::Create`. 2. Producer-request drafts (`submit` action via `WinePackagesController`). |
| **Serializers** | `WinePackageSerializer` (full, viewer-scoped, `can:` capabilities), `WinePackageListSerializer` (lean list), `WinePackageItemSerializer`. |

---

## 3. Submission Flow Sequence (Current)

### Public Trade Submission (anonymous)
```
TradeSubmit.tsx (React)
  → POST /api/v1/trade/submissions (Turnstile verified)
  → Trade::Submissions::Create.call
      → WinePackage.create!(source: "trade_submission", status: "editorial_pending", contact_snapshot, wines→items)
      → WinePackageEvent "trade_submitted"
      → generate_guest_token!
      → store idempotency key
  → Returns { package, guest_token }
```

### Producer Request Submission
```
WinePackageForm.tsx (producer member)
  → PATCH /api/v1/wine_packages/:id (submit action)
  → WinePackagesController#submit
      → transition_to!("requested")
      → WinePackageEvent "submitted"
```
---

## 4. Inconsistency Audit — Full Table

| # | Plan Assumption | Reality | Resolution |
|---|-----------------|---------|------------|
| 1 | Design invoice model from scratch | `wine_package_invoices` exists, Stripe-owned, quote-driven | **Extend** existing table with `payment_source` discriminator + review-fee snapshot fields (user decision) |
| 2 | Overdue must be derived, never stored | `overdue` is a stored enum value; `scope :payable` includes it | Never set `overdue` in manual flow; derive display state from `due_at` + unpaid; keep enum for legacy Stripe compatibility |
| 3 | Submission/review/payment statuses independent | `WinePackage.status` couples payment (`invoiced`, `paid`) | No new column; derive package payment state from invoice records in `WinePackages::BillingSummary`; state machine untouched |
| 4 | Currency AUD | Existing invoices/quotes default EUR | Fee setting defaults AUD; every new record snapshots its own currency; legacy rows unchanged |
| 5 | "Billable bottle count" undefined | Items carry `quantity`, `review_requested` | Estimate = Σ `items.quantity`; package-level staff-confirmed `billable_bottle_count`; each invoice snapshots its own delta |
| 6 | Repo `wine_words_frontend`, docs at `docs/FUTURE/Billing/…` | Actual: `wine_words/`, `docs/IDENTITY_214_…/` | Correct paths in plan doc |
| 7 | "Add billing models/services" | `Billing::` namespace taken by subscriptions | New services under `WinePackages::` (`BillingSummary`, `RecordInvoice`, etc.) |
| 8 | Single submission flow | Two paths exist (anonymous guest + producer request) | Snapshot at trade-submission creation AND at producer-request `submit`; staff-created packages snapshot on accept |
| 9 | "Add API endpoints for billing summary" as new | Trade invoice endpoints partially exist | New nested billing endpoints only for manual workflow; Stripe endpoints untouched |
| 10 | Field names `invoice_sent_at`, `invoice_due_date`, `invoice_paid_at` | Existing: `issued_at`, `due_at`, `paid_at` | Reuse existing columns |
| 11 | Generic migration names | Timestamped descriptive names (`20261122xxxxxx_add_review_fee_billing.rb`) | Follow project convention |

---

## 5. Open Questions (Documented, Not Blocking)

| Question | Default/Decision | Where Resolved |
|----------|------------------|----------------|
| Tax/GST on manual invoices? | Default 0, staff-editable in `tax` column | Phase 4 |
| Can Reviewers (not just Admin/Editor) record invoices? | Default: **no** — `catalogue_manager?` only | Phase 5 policy |
| Does any job auto-set stored `overdue` on Stripe invoices? | Investigate in Phase 4; document | Phase 4/10 |
| Should legacy packages backfill estimate at AUD 50? | **No** — show "not priced under current billing workflow" | Phase 4 migration |
| Waived vs Cancelled separate states? | No — `cancelled` + `cancellation_reason: "waived"` | Phase 1 |

---

## 6. Locked Design Decisions (from Phase 0 + user confirmation)

1. **Extend `WinePackageInvoice`** — one table for Stripe + manual invoices, discriminated by `payment_source` (`stripe` | `manual`).
2. **Historical snapshots immutable**: submission estimate on package; unit fee/currency/count/total on each invoice.
3. **No gateway, no PDF, no auto-email** — staff records externally-sent invoices.
4. **Overdue derived** for display; stored enum value left for legacy Stripe path.
5. **Server-authoritative money** — never trust client totals; `BigDecimal` only.
6. **No backfill** — legacy packages show "not priced under current billing workflow".
7. **Waived** = `cancelled` status + `cancellation_reason: "waived"` (no new enum).
8. **Authorization**: billing management = `catalogue_manager?` (Admin/Editor); owner/guest = read-only.
9. **Namespace** — new services under `WinePackages::`; `Billing::` stays subscription-only.
10. **Currency** — fee setting default AUD; every record snapshots its own currency.
---

## 7. Files Inventoried (Key Paths)

### Backend
```
wine_words_api/
├── app/
│   ├── models/
│   │   ├── wine_package.rb
│   │   ├── wine_package_item.rb
│   │   ├── wine_package_invoice.rb
│   │   ├── wine_package_quote.rb
│   │   ├── wine_package_event.rb
│   │   ├── app_setting.rb
│   │   └── concerns/
│   ├── controllers/
│   │   ├── api/v1/
│   │   │   ├── trade/
│   │   │   │   ├── submissions_controller.rb
│   │   │   │   ├── packages_controller.rb
│   │   │   │   ├── invoices_controller.rb
│   │   │   │   └── payments_controller.rb
│   │   │   ├── wine_packages_controller.rb
│   │   │   ├── wine_package_items_controller.rb
│   │   │   ├── configurations_controller.rb
│   │   │   └── billing_controller.rb
│   │   └── concerns/auditable.rb
│   ├── services/
│   │   ├── trade/
│   │   │   ├── submissions/create.rb
│   │   │   ├── invoices/generate_from_quote.rb
│   │   │   └── payments/
│   │   └── log_service.rb
│   ├── serializers/
│   │   ├── wine_package_serializer.rb
│   │   ├── wine_package_list_serializer.rb
│   │   └── wine_package_item_serializer.rb
│   └── policies/
│       └── wine_package_policy.rb
├── config/routes.rb
└── db/migrate/
    ├── 20260918000001_create_wine_packages.rb
    ├── 20261114000004_create_trade_quotes_and_invoices.rb
    └── 20261121121400_create_wine_packages_history_table.rb
```

### Frontend
```
wine_words/
├── src/
│   ├── components/
│   │   ├── TradeSubmit.tsx
│   │   ├── TradeAdminPackageDetail.tsx
│   │   ├── TradePackageDetail.tsx
│   │   ├── TradeMyPackages.tsx
│   │   ├── WinePackageForm.tsx
│   │   ├── WinePackageDetail.tsx
│   │   ├── WinePackages.tsx
│   │   └── trade.module.css / winePackages.module.css
│   ├── services/
│   │   └── packagesApi.ts
│   ├── types/
│   │   └── winePackage.ts
│   └── pages/ (routes defined in react-router config)
```

---

## 8. Risks Identified

| Risk | Impact | Mitigation |
|------|--------|------------|
| Existing `WinePackageInvoice` validations may reject manual invoices (e.g., `items_priceable` expects unit_price per item) | High | Add `payment_source` conditional validations; manual invoices compute total = unit_fee × count |
| `Trade::Invoices::GenerateFromQuote` hardcodes `status: "sent"` | Medium | Manual flow uses separate service; no conflict |
| `overdue` scope used in existing views/queries | Medium | Manual invoices never set `overdue`; derived display only |
| Two submission paths need identical snapshot logic | Medium | Extract `WinePackages::CaptureEstimate` service shared by both |
| Currency mismatch (AUD fee vs EUR existing) | Low | Every record snapshots its own currency; no conversion |
| `AppSetting` RESERVED_KEYS collision | Low | Add new keys to `RESERVED_KEYS` |
| Pundit policy gap for billing | Medium | Add `manage_billing?` / `view_billing?` to `WinePackagePolicy` |

---

## 9. Deliverables This Phase

- ✅ This audit document (`PHASE_00_AUDIT.md`)
- ✅ Architecture summary (sections 1–3)
- ✅ File inventory (section 7)
- ✅ Conflict table + resolutions (section 4)
- ✅ Locked decisions (section 6)
- ✅ Risks (section 8)
- ⏳ Phase 1 domain model doc (next)
- ⏳ Original plan `.md` amendments (after Phase 1)

---

*No implementation changes made in this phase. Proceeding to Phase 1 documentation.*