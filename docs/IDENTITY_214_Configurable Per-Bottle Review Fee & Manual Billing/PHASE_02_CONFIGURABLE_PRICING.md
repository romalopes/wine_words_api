# Phase 2 — Configurable Global Pricing
**Status:** ✅ Completed
**Date:** 2026-11-22
**Depends on:** Phase 1 Domain Model

---

## 1. Objective

Implement a single source of truth for the Wine Words review fee (AUD $50.00/bottle initial default) using the existing `AppSetting` architecture, with admin-only update capability and public read access.

---

## 2. Backend Changes

### 2.1 AppSetting Model (`app/models/app_setting.rb`)

**New DEFAULTS:**
```ruby
"wine_review_fee_amount" => "50.00",
"wine_review_fee_currency" => "AUD"
```

**Added to RESERVED_KEYS:**
```ruby
%w[
  logs_enabled use_test_email test_email mail_transport
  wine_review_fee_amount wine_review_fee_currency
]
```

**New Accessor Methods:**
| Method | Purpose |
|--------|---------|
| `wine_review_fee_amount` | Returns `BigDecimal` for safe monetary calculations |
| `wine_review_fee_currency` | Returns ISO 4217 currency code (String) |
| `wine_review_fee_amount_formatted` | Returns `"50.00"` format for JSON serialization |
| `validate_wine_review_fee!(amount, currency)` | Validates: non-negative, ≤2 decimal places, supported currency |

**Supported Currencies:** AUD, USD, EUR, GBP, NZD, CAD, CHF, JPY

### 2.2 ConfigurationsController (`app/controllers/api/v1/configurations_controller.rb`)

**GET /api/v1/configuration** — Returns all settings including:
```json
{
  "wine_review_fee_amount": "50.00",
  "wine_review_fee_currency": "AUD",
  ...
}
```

**PATCH /api/v1/configuration** — Admin-only, accepts:
- Flat: `{ wine_review_fee_amount: "75.50", wine_review_fee_currency: "USD" }`
- Nested: `{ configuration: { wine_review_fee_amount: "75.50", ... } }`
- Validates via `AppSetting.validate_wine_review_fee!`
- Returns 422 with error message on invalid input

### 2.3 Public Pricing Endpoint

**Controller:** `app/controllers/api/v1/trade/pricing_controller.rb`

**Route:** `GET /api/v1/trade/pricing` (in `trade` namespace, unauthenticated)

**Response:**
```json
{
  "wine_review_fee": {
    "amount": "50.00",
    "currency": "AUD",
    "unit": "bottle"
  }
}
```

---

## 3. Frontend Changes (Planned for Phase 6)

The admin Configuration page will need:
- Fee amount input (number, step="0.01", min="0")
- Currency selector (AUD, USD, EUR, GBP, NZD, CAD, CHF, JPY)
- Warning: "Changes affect future submissions only; existing package snapshots are not modified"
- Save button

TradeSubmit.tsx will fetch from `GET /api/v1/trade/pricing` (Phase 3).

---

## 4. Tests Added

### Configurations Spec (`spec/requests/api/v1/configurations_spec.rb`)
- ✅ GET returns defaults including fee fields
- ✅ PATCH persists fee amount and currency
- ✅ PATCH accepts nested fee payload
- ✅ Rejects negative amount
- ✅ Rejects >2 decimal places
- ✅ Rejects unsupported currency
- ✅ Leaves fee untouched when absent

### Trade Pricing Spec (`spec/requests/api/v1/trade/pricing_spec.rb`)
- ✅ GET returns default fee without authentication
- ✅ GET returns updated fee after admin change

---

## 5. Verification

| Test Suite | Result |
|------------|--------|
| `spec/requests/api/v1/configurations_spec.rb` | 20 examples, 0 failures |
| `spec/requests/api/v1/trade_spec.rb` | 34 examples, 0 failures |
| `spec/requests/api/v1/trade/pricing_spec.rb` | 2 examples, 0 failures |

All 56 related tests pass. Pre-existing 51 failures in unrelated specs are unchanged.

---

## 6. Files Changed

| File | Change Type |
|------|-------------|
| `app/models/app_setting.rb` | Added fee keys, accessors, validation |
| `app/controllers/api/v1/configurations_controller.rb` | Expose/update fee settings |
| `app/controllers/api/v1/trade/pricing_controller.rb` | New public pricing endpoint |
| `config/routes.rb` | Added `get "pricing"` in trade namespace |
| `spec/requests/api/v1/configurations_spec.rb` | Updated defaults test + 7 new fee tests |
| `spec/requests/api/v1/trade/pricing_spec.rb` | New spec file (2 tests) |

---

## 7. Phase Status Update

| Phase | Status |
|-------|--------|
| 0 | ✅ Completed |
| 1 | ✅ Completed |
| 2 | ✅ Completed |
| 3 | ⏳ Pending |
| 4 | ⏳ Pending |
| 5 | ⏳ Pending |
| 6 | ⏳ Pending |
| 7 | ⏳ Pending |
| 8 | ⏳ Pending |
| 9 | ⏳ Pending |
| 10 | ⏳ Pending |
| 11 | ⏳ Pending |

---

*Next: Phase 3 — Submission Page Pricing & Estimate*