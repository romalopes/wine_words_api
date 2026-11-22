# Phase 13 — Submitter Shipment Tracking
**Status:** ✅ Completed
**Date:** 2026-11-22
**Depends on:** IDENTITY_206 trade submission workflow

---

## 1. Objective

Allow the submitter (package owner, in **My Packages**) to set the shipment
tracking information for their package — carrier, consignment number, URL and
estimated delivery. The Wine Words team can see and edit everything from the
package management page, and arrival confirmation stays editorial.

---

## 2. Authorisation Changes

### `WinePackagePolicy`

| Change | Detail |
|--------|--------|
| New `submitter?` predicate (public) | `user && record.submitter_id == user.id` — exposed like `producer_member?` so controllers can branch parameter sets |
| `show?` | Now also true for the submitter — claimed submitters could not even VIEW the package/tracking before (the claim flow sets `submitter_id`, never `created_by_id`) |
| `manage_tracking?` | Now also true for the submitter, at any package stage — they ship the wine. Restricted field subset still applies; provider refreshes (`refresh_tracking?`) stay editorial-only |

### `ShipmentTrackingsController#tracking_params`

Restricted subset now applies to `producer_member? OR submitter?`:
- Permitted: `carrier`, `number`, `url`, `estimated_delivery_at`
- Rejected: `provider`, `status`, `delivered_at` — delivery status is
  maintained by the Wine Words team and carrier refreshes; physical arrival
  is confirmed editorially.

---

## 3. Frontend Changes

### `ShipmentTrackingPanel.tsx`

| Change | Detail |
|--------|--------|
| New `restricted` prop | Submitter/owner mode: hides the Status field (the server ignores it for restricted users) and omits `status` from the save payload. `producerMode` behaviour is unchanged (ID_210 guard). |
| Fixed Save/Refresh gating bug | "Save tracking" was gated on `canRefresh` and "Refresh from carrier" was unconditional — a producer/submitter with `canManage=true, canRefresh=false` saw a form with ONLY a Refresh button that would 403. Now Save shows whenever the form renders (`canManage`), Refresh only when `canRefresh`. |

### `TradePackageDetail.tsx` (My Packages → package detail)

- Renders `ShipmentTrackingPanel` for the authenticated owner view
  (`!guestToken`) with `canManage`, `canRefresh={false}`, `restricted`.
- `onChanged` reloads the package so the hero status stays fresh.
- Guest-token views render nothing (tracking endpoints require auth).

**Team visibility/edit:** unchanged — the existing `ShipmentTrackingPanel` on
`WinePackageDetail.tsx` (`can.manage_tracking` / `can.refresh_tracking`
capabilities) gives Admin/Editor full read/write including status,
`delivered_at`, provider override and carrier refresh.

---

## 4. Tests

Added to `spec/requests/api/v1/shipment_trackings_spec.rb`
("submitter tracking access" — 5 examples):

| Test | Assertion |
|------|-----------|
| Submitter can view the tracking row | 200 with carrier/number |
| Submitter can record carrier, number, ETA | 201; package snapshot synced; `tracking_status` nil |
| Delivery status sent by submitter is ignored | 201; `tracking_status` stays nil |
| Submitter cannot refresh provider history | 403 |
| Unrelated user still gets 404 | 404 (no package-existence leak) |

---

## 5. Verification Results

| Check | Result |
|-------|--------|
| `shipment_trackings_spec.rb` | ✅ 18 examples, 0 failures |
| Full backend suite (related specs) | ✅ 133 examples, 0 failures |
| `tsc --noEmit` — new/changed files | ✅ 0 errors (only pre-existing baseline errors remain, incl. `TradePackageDetail` TradeMessagesProps which predates this work) |
| `npm run build` | ✅ built (Vite + PWA) |
| Full frontend suite | ✅ 7 failed / 637 passed — identical to pre-change baseline |

---

## 6. Files Changed

| File | Change |
|------|--------|
| `app/policies/wine_package_policy.rb` | `submitter?` predicate; `show?` + `manage_tracking?` extended |
| `app/controllers/api/v1/shipment_trackings_controller.rb` | Restricted param subset for submitters |
| `spec/requests/api/v1/shipment_trackings_spec.rb` | 5 new submitter examples |
| `src/components/ShipmentTrackingPanel.tsx` | `restricted` prop; Save/Refresh gating fix |
| `src/components/TradePackageDetail.tsx` | Panel embedded for the owner view + reload callback |

---

## 7. Design Notes / Decisions

1. **Submitter can manage tracking at any stage** — the shipping leg belongs
   to the submitter; the restricted field subset makes this safe (they cannot
   touch provider, delivery status, `delivered_at`, or event history).
2. **Refresh stays editorial-only** — provider refreshes resolve external
   carrier APIs and append event history; staff trigger it from the package
   page. The submitter panel hides the Refresh button (`canRefresh={false}`).
3. **Claimed vs guest** — the claim flow sets `submitter_id` only, so the
   policy predicates key off `submitter_id`. Guest-token holders never reach
   these authed endpoints.
4. **Scope note** — `WinePackagePolicy::Scope` was left unchanged; the
   trade "my packages" list uses the dedicated trade endpoint
   (`submitter_id = current_user`), so list visibility is unaffected.
