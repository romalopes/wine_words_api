# Phase 3 — Submission Page Pricing & Estimate
**Status:** ✅ Completed
**Date:** 2026-11-22
**Depends on:** Phase 2 Configurable Pricing

---

## 1. Objective

Make the review fee transparent before the user submits a package. The submission form (TradeSubmit) fetches the current configured fee, calculates a live estimate based on bottle count, and displays clear messaging that no payment is collected at submission and that Wine Words confirms the final billable count.

---

## 2. Frontend Changes

### 2.1 TradeApi (`src/services/tradeApi.ts`)

Added `getPricing()` method:
```typescript
getPricing() {
  return request<{
    wine_review_fee: { amount: string; currency: string; unit: string }
  }>("/trade/pricing")
}
```

### 2.2 TradeSubmit Component (`src/components/TradeSubmit.tsx`)

**New State:**
- `pricing` — current fee info (amount, currency, unit)
- `pricingLoading` — loading state
- `pricingError` — error state

**New Effects:**
- Fetch pricing on component mount from `GET /api/v1/trade/pricing`

**New Computed Values:**
- `bottleCount` — total bottles based on entry mode (quantity mode = wineQuantity; details mode = sum of wine.quantity)
- `estimatedTotal` — `pricing.amount × bottleCount`, formatted to 2 decimal places

**New UI — Pricing Panel (Review Step):**
```
┌─────────────────────────────────────┐
│ Pricing                             │
├─────────────────────────────────────┤
│ Fee per bottle:     AUD 50.00       │
│ Bottles submitted:  6               │
│ Estimated total:    AUD 300.00      │
├─────────────────────────────────────┤
│ ⚠ No payment is collected at        │
│   submission. This is an estimate   │
│   based on the current fee and the  │
│   number of bottles in your         │
│   submission. Wine Words confirms   │
│   the final billable bottle count   │
│   after review and will send a      │
│   separate invoice for the          │
│   confirmed amount.                 │
└─────────────────────────────────────┘
```

**Loading/Error States:**
- Loading: "Loading pricing…"
- Error: Shows error message with `role="alert"`
- Fallback: "Pricing information will appear once loaded."

**Live Updates:**
- Bottle count updates immediately when wines are added/removed in details mode
- Bottle count updates when quantity selector changes in quantity mode
- Estimated total recalculates automatically

### 2.3 CSS Styles (`src/components/trade.module.css`)

Added pricing panel styles:
- `.pricingPanel` — container with subtle background
- `.pricingDetails` — definition list grid layout
- `.pricingNote` — styled warning message

---

## 3. Backend Snapshot Capture (Planned for Phase 4)

The server-side estimate snapshot capture will be implemented in `Trade::Submissions::Create`:
- Reads current fee from `AppSetting`
- Counts submitted bottles
- Calculates and persists snapshot on `wine_packages` table
- Client totals are ignored — server is authoritative

---

## 4. Verification

| Test | Result |
|------|--------|
| Backend pricing endpoint (`spec/requests/api/v1/trade/pricing_spec.rb`) | ✅ 2 examples, 0 failures |
| Backend configurations endpoint | ✅ 20 examples, 0 failures |
| Trade submissions endpoint | ✅ 34 examples, 0 failures |
| Frontend type-check | Pre-existing errors only (no new errors from TradeSubmit) |

---

## 5. Files Changed

| File | Change Type |
|------|-------------|
| `src/services/tradeApi.ts` | Added `getPricing()` method |
| `src/components/TradeSubmit.tsx` | Added pricing state, fetch, calculations, UI panel |
| `src/components/trade.module.css` | Added pricing panel styles |

---

## 6. Phase Status Update

| Phase | Status |
|-------|--------|
| 0 | ✅ Completed |
| 1 | ✅ Completed |
| 2 | ✅ Completed |
| 3 | ✅ Completed |
| 4 | ⏳ Pending |
| 5 | ⏳ Pending |
| 6 | ⏳ Pending |
| 7 | ⏳ Pending |
| 8 | ⏳ Pending |
| 9 | ⏳ Pending |
| 10 | ⏳ Pending |
| 11 | ⏳ Pending |

---

*Next: Phase 4 — Database Migrations and Invoice Model (server-side snapshot capture, new columns, BillingSummary service)*