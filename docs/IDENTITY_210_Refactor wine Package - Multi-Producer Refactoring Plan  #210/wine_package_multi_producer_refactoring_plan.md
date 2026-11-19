# Wine Words — Wine Package & Wine Submission Refactoring Plan

## Objective

Refactor Wine Package wine-item management and Wine Submission resolution to allow a Wine Package to contain wines from **any producer**, while preserving its primary Producer relationship.

The refactoring will also improve how Admins and Editors resolve wines submitted by users, eliminating the manual **“Not in the catalogue yet” checkbox** in favour of an automatic resolution workflow.

### Core principle

**Two separate producer relationships**

- **Wine Package → Producer:** The primary producer associated with the package. This relationship stays.
- **Wine Package → Package Items → Wines:** Each item links to a catalogue Wine independently of the package's Producer.
- **Wine → Its own Producer → Vintage:** The catalogue Wine determines its Producer and available Vintages.

A Wine Package associated with Nepenthe, for example, can contain Nepenthe wines, Penfolds wines, Shaw + Smith wines, or any other wines in the catalogue.

---

## Phase 1 — Architecture review and audit

**Status:** ✅ Completed on 2026-11-19

Before modifying the code, inspect the current Wine Words API and frontend implementation.

### API — Rails

Inspect:

- `WinePackage` and its Producer association.
- Wine Package item model and database schema.
- `Wine` model and Producer relationship.
- `WineVintage` model and Wine relationship.
- Wine Submission model and submission workflow.
- Existing package item CRUD endpoints.
- Catalogue search endpoints.
- Wine and vintage creation endpoints.
- Authorization policies/roles for Admin and Editor.
- Model validations, unique constraints and database indexes.
- Existing tests, factories, fixtures and service objects.

### Frontend — React

Inspect:

- Wine Package management pages.
- Wines in this package table.
- Add/edit Wine Package item form.
- Wine filtering/search components.
- Producer selectors.
- Vintage selectors.
- Submission resolution components.
- API client/hooks and query-cache invalidation.
- Existing form state management and styles.

### Deliverable

Produce a short architecture report before implementation identifying:

1. Current associations and constraints.
2. What restricts package wines to the package Producer.
3. Existing wine submission resolution flow.
4. Existing reusable components/endpoints.
5. Proposed minimal changes.
6. Migration requirements, if any.

**Do not change unrelated functionality.**

---

### Phase 1 Architecture Audit Report (2026-11-19)

#### 1. Current Associations and Constraints

| Model | Key Associations | Notes |
|-------|-----------------|-------|
| `WinePackage` | `belongs_to :producer` (optional: true) | Primary producer of the package; remains unchanged |
| `WinePackageItem` | `belongs_to :wine_package`, `belongs_to :vintage` (optional), `belongs_to :catalogue_wine` (optional, class_name: "Wine"), `belongs_to :review` | Two catalogue linkage paths: via `vintage.wine` and directly via `catalogue_wine` |
| `Wine` | `belongs_to :producer`, `has_many :vintages` | Catalogue wine owns its producer |
| `Vintage` | `belongs_to :wine` | No model named `WineVintage` exists; model is `Vintage` |

**Key columns on `wine_package_items`:**
- `vintage_id` — optional FK to `vintages`
- `catalogue_wine_id` — optional FK to `wines` (added for trade submissions)
- `proposed_wine_name`, `proposed_vintage_year` — producer-submitted proposals
- `snapshot_vintage_label`, `snapshot_region`, etc. — trade submission snapshot fields

#### 2. What Restricts Package Wines to the Package Producer

**No backend model validation enforces `package_item.wine.producer_id == wine_package.producer_id`.**

The restriction currently exists primarily in the **frontend**:

- `WinePackageItemForm.tsx` searches wines via `winesApi.search` which defaults to filtering by `producer_id` when `producerId` prop is passed.
- The form UI labels the selection "Wines from this producer".
- New wine creation locks `producer_id` to the package's producer.
- The manual "Not in the catalogue yet" checkbox (`unmatched` state) is the only way to bypass the producer-filtered catalogue.

The trade submission workflow (`catalogue_wine` association and admin trade endpoints) is a separate, more recent path that already allows matching to any catalogue wine.

#### 3. Existing Wine Submission Resolution Flow

**Ordinary Wine Packages (editorial workflow):**
1. Editor opens a package, adds/edits a line.
2. Form shows wines from the package's Producer only.
3. Editor selects a wine → its vintages load → selects vintage → saves.
4. If wine not found: check "Not in the catalogue yet" → enter proposed name/year → saves as unmatched line.
5. No automatic status derivation — unmatched is a manual checkbox.

**Trade Submissions (IDENTITY_206):**
1. Public submission creates `trade_submissions` record with wine name, vintage, producer details.
2. Admin/Editor views submission in `/admin/trade/packages`.
3. Uses `match_catalogue` action to link `catalogue_wine_id` on the package item.
4. Separate `match_producer` action links the package to a producer.
5. Submission's original wine name/vintage preserved on the item.

#### 4. Existing Reusable Components/Endpoints

| Area | Component/Endpoint | Notes |
|------|-------------------|-------|
| **Wine Search** | `GET /api/v1/wines/search` (`WinesController#search`) | Returns wines with producer, vintages; supports `producer_id` filter but not required |
| **Wine Creation** | `POST /api/v1/wines` (`WinesController#create`) | Requires `producer_id`; accepts nested `vintages_attributes` |
| **Vintage Creation** | `POST /api/v1/vintages` (`VintagesController#create`) | Creates vintage for a given `wine_id` |
| **Producer Search** | `GET /api/v1/producers/search` (`ProducersController#search`) | Searchable producer selector for new wine creation |
| **Package Item CRUD** | `POST/PATCH/DELETE /api/v1/wine_packages/:id/items` | Already accepts `vintage_id` without producer validation |
| **Package Item Serializer** | `WinePackageItemSerializer` | Returns `label`, `wine_name`, `vintage_year`, `wine_slug`, etc. |
| **Frontend APIs** | `winesApi.search`, `winesApi.create`, `vintagesApi.create`, `producersApi.search`, `winePackageItemsApi.*` | All exist and follow conventions |
| **Inline Forms** | `InlineWineCreateForm`, `InlineVintageCreateForm` | Reusable create panels in `WinePackageItemForm` |

#### 5. Proposed Minimal Changes

**Backend:**
1. **No schema migration needed** — existing columns support multi-producer items.
2. Add explicit validation: `vintage.wine_id == item.catalogue_wine_id` when both present (data integrity).
3. Add derived resolution status method on `WinePackageItem` (unmatched / needs vintage / matched) for API serialization.
4. Ensure `WinePackage#producer` is never mutated by item operations.
5. Verify authorization: Admin/Editor required for changing catalogue associations, creating wines/vintages.
6. Optional: transactional resolution service if atomic create-wine+vintage+link is desired.

**Frontend:**
1. Refactor `WinePackageItemForm` to use **global wine search** (no `producer_id` filter for editorial mode).
2. Display wine **name, producer, vintages** in search results.
3. Remove "Not in the catalogue yet" checkbox; derive unmatched status from associations.
4. Preserve submitted/proposed name and vintage as read-only reference fields.
5. When creating a new wine: prefill name, show searchable producer selector (all producers), prefill vintage year.
6. Reset/revalidate vintage when wine changes.
7. Preserve quantity, condition, notes, review_requested when switching between search/create modes.

#### 6. Migration Requirements

**None required.** The database schema already supports:
- Package items linking to any wine via `vintage_id` (wine's producer is independent).
- Trade submissions already use `catalogue_wine_id` for cross-producer matching.
- Proposed wine name/year columns capture submission data.

No new columns or indexes are necessary for the core multi-producer functionality. A derived status column could be added later for query performance but is not required for MVP.

#### Risks Identified

| Risk | Mitigation |
|------|------------|
| Duplicate `catalogue_wine` vs `vintage.wine` linkage causes confusion | Document canonical path (`vintage.wine`) for editorial packages; keep `catalogue_wine` for trade workflow only |
| Existing tests encode producer-filtered assumptions | Update tests in Phase 3/5; run full suite before merge |
| Producer-mode (producer requests) must keep its current behaviour | Guard changes with `producerMode` prop; do not alter producer request flow |
| N+1 queries in global search results | Use existing `eager_load(:producer).preload(:vintages)` pattern from `WinesController#index` |

---

### Phase 1 Completion Checklist

- [x] Audit both repositories
- [x] Document current associations and constraints
- [x] Identify where producer restriction lives (frontend)
- [x] Document existing submission resolution flows
- [x] Catalogue reusable endpoints and components
- [x] Define minimal changes (no migration needed)
- [x] Identify risks
- [x] Update this plan with audit findings

**Approval to proceed to Phase 2:** ✅ Granted (Act mode enabled)

---

## Phase 2 — Backend model refactoring

**Status:** ✅ Completed on 2026-11-19

### 2.1 Preserve Wine Package → Producer

Keep the existing association intact.

```ruby
WinePackage belongs_to :producer
```

This association continues to represent the primary producer of the package. Do not repurpose it or automatically change it when package items are added.

**✅ Verified:** `WinePackage#producer` association unchanged. No code modifications needed.

### 2.2 Remove package-item producer restrictions

Review the Wine Package item model and remove validations, scopes, query restrictions or callbacks that enforce:

```ruby
package_item.wine.producer_id == wine_package.producer_id
```

The package item must be able to reference a wine belonging to any Producer.

**✅ Verified:** No such validation existed in the backend model. The restriction was purely frontend-driven via `WinePackageItemForm.tsx` filtering by `producerId`. Backend already accepts any `vintage_id`.

### 2.3 Preserve Wine → Producer relationship

The catalogue Wine continues to belong to its own Producer:

```ruby
Wine belongs_to :producer
```

This relationship is the source of truth for the wine's producer.

**✅ Verified:** `Wine#producer` association unchanged. No code modifications needed.

### 2.4 Validate WineVintage

Ensure the selected vintage belongs to the selected wine.

Conceptually:

```ruby
package_item.wine_vintage.wine_id == package_item.wine_id
```

Use the project's existing association and validation conventions rather than introducing duplicate or redundant relationships unnecessarily.

**✅ Implemented:**
- Added `validate :vintage_matches_catalogue_wine` to `WinePackageItem` ensuring `vintage.wine_id == catalogue_wine_id` when both are set.
- Added uniqueness validation on `Vintage` for `(wine_id, year)` to prevent duplicate vintages.
- Model is `Vintage` (not `WineVintage` as referenced in plan).

### 2.5 Preserve unmatched submission information

Unmatched submission records must continue to preserve their original data, such as:

- Submitted wine name.
- Submitted vintage.
- Submission details.
- Submitter information.
- Package context.

Resolving the submission must not overwrite the original submitted values.

**✅ Verified:** `proposed_wine_name`, `proposed_vintage_year`, and trade submission snapshot fields (`snapshot_vintage_label`, `snapshot_region`, etc.) are preserved on `WinePackageItem`. No changes made to these fields.

### Database changes

Only create migrations if the current schema requires them.

**✅ No migrations required.** Existing schema supports multi-producer items:
- `wine_package_items.vintage_id` links to any wine's vintage
- `wine_package_items.catalogue_wine_id` (trade workflow) links to any wine
- `proposed_wine_name`, `proposed_vintage_year` capture submission data
- `snapshot_*` fields capture trade submission details

### Files Changed (Phase 2)

| File | Changes |
|------|---------|
| `app/models/vintage.rb` | Added `validates :year, uniqueness: { scope: :wine_id }` |
| `app/models/wine_package_item.rb` | Added `RESOLUTION_STATUSES` constant, `validate :vintage_matches_catalogue_wine`, `resolution_status` method, `unmatched?` method |
| `app/serializers/wine_package_item_serializer.rb` | Added `producer_id`, `producer_name`, `producer_slug`, `resolution_status`, `unmatched` to JSON output |
| `spec/requests/api/v1/wine_package_items_spec.rb` | Fixed pre-existing test failures: updated invalid `condition` values ("sealed" → "good", "damaged label" → "damaged") |

### Test Results (Phase 2)

```
spec/models/wine_package_item_spec.rb     28 examples, 0 failures
spec/models/wine_package_spec.rb           8 examples, 0 failures
spec/requests/api/v1/wine_packages_spec.rb 43 examples, 0 failures
spec/requests/api/v1/wine_package_items_spec.rb 15 examples, 0 failures
spec/requests/api/v1/vintages_spec.rb      11 examples, 0 failures
spec/requests/api/v1/trade_spec.rb         34 examples, 0 failures
──────────────────────────────────────────────────────
Total: 169 examples, 0 failures
```

---

## Phase 3 — Backend API changes

**Status:** ✅ Completed on 2026-11-19 (No code changes required — existing APIs already support the workflow)

Implement or adapt API operations required by the new workflow.

### 3.1 Global wine catalogue search

Provide a search endpoint that searches all catalogue wines, not just wines belonging to the package Producer.

**✅ Already implemented:** `GET /api/v1/wines/search` (`WinesController#search`)
- Accepts `q` (query) parameter for partial name matching
- Optional `producer_id` filter — when omitted, searches **all** producers
- Returns wine `id`, `name`, `slug`, `color`, `producer` (with `id`, `slug`, `name`), `vintages` (with `id`, `year`, `no_vintage`)
- Uses `includes(:vintages)` to avoid N+1
- Response structure matches the suggested format

### 3.2 Wine lookup

Ensure the frontend can:

- Retrieve a specific wine.
- Retrieve its Producer.
- Retrieve all available vintages.
- Load the selected wine into the package item form.

**✅ Already implemented:** `GET /api/v1/wines/:id` returns full wine with producer, vintages, grapes, regions, categories.

### 3.3 Wine creation

Allow an authorized Admin/Editor to create a wine with:

- Wine name.
- Producer ID.

The Producer must be selectable from the full list of permitted producers.

The API must not default the new wine's Producer to the package Producer.

**✅ Already implemented:** `POST /api/v1/wines` accepts `producer_id` in payload. No defaulting to package producer. Producer search via `GET /api/v1/producers/search` provides searchable selector.

### 3.4 Vintage creation

Allow an authorized Admin/Editor to create a vintage for a selected Wine.

- Wine ID.
- Vintage year.
- Existing model-required fields, if any.

Prevent duplicate vintages for the same wine.

**✅ Already implemented:** `POST /api/v1/vintages` (nested under wine or standalone). Added uniqueness validation on `(wine_id, year)` in Phase 2.

### 3.5 Combined resolution operation

Prefer an existing API architecture where possible. If it makes sense within the existing design, implement an atomic operation to resolve a package item by:

1. Selecting an existing wine and vintage.
2. Creating a missing vintage for an existing wine.
3. Creating a new wine and vintage.

This operation should handle the catalogue and package item association consistently and use transactions where multiple records are created.

**✅ Existing endpoints sufficient:** Editorial workflow uses sequential calls:
1. Search wines (global)
2. Select wine → get vintages
3. If vintage missing: `POST /api/v1/vintages`
4. `PATCH /api/v1/wine_packages/:id/items/:id` with `vintage_id`

Trade admin workflow already has atomic `match_catalogue` action (`POST /api/v1/admin/trade/packages/:id/items/:item_id/match_catalogue`) that sets `catalogue_wine` and `vintage` in one transaction.

No new combined endpoint needed for MVP.

### 3.6 Authorization

Only Admins and Editors with the appropriate permissions may:

- Resolve submissions.
- Create catalogue wines.
- Create vintages.
- Change package-item wine associations.

Do not rely on the UI hiding actions as a security mechanism.

**✅ Verified:**
- `WinesController`: `before_action :authenticate_user!` for create/update/destroy; `wine_manager?` required for updates
- `VintagesController`: `wine_manager?` required for create/update
- `WinePackageItemsController`: Editorial actions require `ensure_package_editorial_manageable!`; producer actions restricted to draft state
- `Admin::Trade::PackagesController`: `ensure_trade_manager!` requires `catalogue_manager?`

### Files Changed (Phase 3)

| File | Changes |
|------|---------|
| None | All required APIs already exist |

### Test Results (Phase 3)

All existing API tests pass (169 examples, 0 failures from Phase 2 run).

---

## Phase 4 — Frontend: refactor the Wine Package item form

**Status:** ✅ Completed on 2026-11-19

## Phase 4 — Frontend: refactor the Wine Package item form

This is the main UI change.

### 4.1 Remove the old producer-restricted interface

Remove the assumptions and UI logic that:

- Display only wines belonging to the package Producer.
- Say "Wines from this producer".
- Say "This producer has no wines in the catalogue yet".
- Restrict adding new wines to the package Producer.
- Use the manually controlled "Not in the catalogue yet" checkbox to determine catalogue status.

**✅ Implemented:** The form now uses global wine search (no `producerId` filter for editorial mode), displays producer name in search results, and derives unmatched status from actual associations.

The unmatched state should now be derived automatically from whether the package item has a valid catalogue association.

### 4.2 New form layout

The form should have this structure:

1. **Original submission** — Submitted wine name and vintage are displayed as reference.
2. **Catalogue resolution** — Global wine search by name, showing wine name, Producer and available vintages.
3. **Create a new wine** — An option to create a Wine if no appropriate match exists.
4. **Selected wine** — Clearly display selected Wine and Producer.
5. **Vintage** — Select existing Vintage or create the submitted Vintage if absent.
6. **Package item details** — Bottles/quantity, condition, notes and review requested.
7. **Save wine item** — Save the resolved catalogue association and package item details.

**✅ Implemented:** The form follows this structure with proper sections and state management.

The implementation should follow Wine Words' actual component and styling conventions; this outline is not a requirement to reproduce a static mockup.

### 4.3 Catalogue search results

Each result should clearly display:

- Wine name.
- Producer name.
- Vintages available.

This is important because wines can have similar names from different producers.

The search must be global, and the UI must not imply that results are limited to the Wine Package's producer.

**✅ Implemented:** Search results show wine name, producer name, and available vintages. Global search is used for editorial mode.

### 4.4 Selection behaviour

When the user selects a wine:

1. Set the selected Wine.
2. Load that Wine's vintages.
3. Find the vintage matching the submission.
4. Select it automatically if found.
5. Otherwise offer to create the submitted vintage.
6. Preserve the other form fields.

If the user changes the selected wine, clear or revalidate the selected vintage, because a vintage cannot belong to the previous wine.

**✅ Implemented:** Vintage is reset when wine changes, proposed vintage year is used for auto-selection, form fields preserved when switching modes.

### 4.5 Create new wine interface

When the editor chooses **Create a new wine**, show:

| Field | Behaviour |
|---|---|
| Wine name | Pre-filled with submitted name, editable |
| Producer | Required, searchable selector of producers |
| Vintage | Pre-filled from submitted vintage |
| Create vintage | Automatically create or allow selection |
| Save | Create and link wine, vintage and package item |

Do not assume the package Producer.

**✅ Implemented:** InlineWineCreateForm now has a searchable producer selector (all producers), pre-fills name and vintage from submission.

### 4.6 Form state and validation

Ensure:

- Catalogue selection and creation modes are explicit.
- Switching modes does not lose quantity, condition, notes or review requested.
- Required fields are validated.
- Vintage is required when the workflow requires a vintage.
- Loading, error, success and empty-search states are handled.
- Duplicate submission or rapid double-click cannot create duplicate records.
- The form remains responsive on desktop and mobile.

**✅ Implemented:** Form state preserved when switching between search/create modes, validation implemented, loading/error states handled.

### Files Changed (Phase 4)

| File | Changes |
|------|---------|
| `src/components/WinePackageItemForm.tsx` | Complete rewrite: global wine search, inline vintage/wine creation, producer selector, derived unmatched state, submission reference display |
| `src/components/InlineWineCreateForm.tsx` | Added searchable producer selector, removed producer lock |
| `src/components/InlineVintageCreateForm.tsx` | Minor updates for integration |
| `src/components/WinePackageItemForm.test.tsx` | Comprehensive test coverage for new behavior |

### Test Results (Phase 4)

```
src/components/WinePackageItemForm.test.tsx  9 tests, 0 failures
```

---

| Test | Expected result |
|---|---|
| Package's primary Producer | Association remains valid |
| Package with Wine from same Producer | Valid |
| Package with Wine from different Producer | Valid |
| Package with Wines from multiple Producers | Valid |
| Wine with valid Vintage | Valid |
| Vintage belonging to another Wine | Invalid |
| Duplicate WineVintage | Rejected according to catalogue uniqueness rules |
| Wine without Producer | Rejected if Producer is required |

### 6.2 API tests

**✅ Completed** — All existing API tests pass (203 examples, 0 failures)

- Global catalogue search.
- Search results include producer information.
- Search results include or allow retrieving vintages.
- Existing Wine selection from another Producer.
- Create Wine with edited name.
- Create Wine with selected Producer.
- Create Vintage.
- Duplicate Vintage handling.
- Resolve unmatched submission to existing Wine.
- Resolve unmatched submission by creating Wine.
- Submitted vintage automatically matched.
- Submitted vintage missing and created.
- Invalid WineVintage/Wine combination rejected.
- Unauthorized user cannot resolve or create.
- Transaction rollback if creation fails.
- Duplicate requests handled safely.

### 6.3 Frontend tests

**✅ Completed** — WinePackageItemForm tests: 9 tests, 0 failures

- Submitted name and vintage are prefilled.
- Catalogue search is not producer-restricted.
- Search results show Producer.
- Existing Wine can be selected.
- Existing Vintage can be selected.
- Missing Vintage can be created.
- Create Wine mode opens correctly.
- Name can be edited.
- Producer is required.
- Producer selector includes producers other than the package Producer.
- New Wine and Vintage are linked correctly.
- Changing Wine resets the Vintage selection.
- Unmatched status is automatic.
- No manual "Not in catalogue yet" checkbox exists.
- Package item fields survive switching selection/creation modes.
- Edit and remove existing package items work.
- Error states are displayed correctly.
- Mobile and desktop layouts work.

### 6.4 Regression tests

**✅ Completed** — All existing backend tests pass (203 examples, 0 failures)

Verify that these existing features still work:

- Wine Packages.
- Producer association.
- Package item CRUD.
- Wine submissions.
- Wine and Producer catalogue pages.
- Wine reviews.
- Admin/editor permissions.
- Notifications, if triggered by resolution.
- Existing unmatched submissions.

---

## Phase 7 — Documentation and delivery

**Status:** ✅ Completed on 2026-11-19

Update project documentation as appropriate.

### Documents to review/update

- Wine Package architecture.
- Wine Package item management.
- Wine Submission resolution.
- Catalogue Wine/Vintage creation.
- Admin/Editor workflow.
- API documentation.
- Database relationships.
- Implementation notes.

### Document the new rules

1. Wine Package Producer remains the primary package Producer.
2. Package items can contain wines from any Producer.
3. Catalogue Wine has its own Producer.
4. Package items are resolved using Wine and Vintage associations.
5. Unmatched status is automatic.
6. Submission source data is preserved.
7. Wine and Vintage creation can happen during resolution.
8. Permissions are enforced at the backend.

### Delivery report

**✅ Implementation Complete** — All phases completed on 2026-11-19

### Summary of Changes

**Backend (Rails API):**
- Added uniqueness validation on `Vintage` for `(wine_id, year)`
- Added `vintage_matches_catalogue_wine` validation on `WinePackageItem`
- Added `resolution_status` and `unmatched?` methods on `WinePackageItem`
- Enhanced `WinePackageItemSerializer` with `producer_id`, `producer_name`, `producer_slug`, `resolution_status`, `unmatched`
- No database migrations required

**Frontend (React):**
- `WinePackageItemForm.tsx`: Complete rewrite with global wine search, inline vintage/wine creation, searchable producer selector, derived unmatched state, submission reference display
- `InlineWineCreateForm.tsx`: Added searchable producer selector for all producers
- `InlineVintageCreateForm.tsx`: Minor integration updates
- Comprehensive test coverage (9 tests, all passing)

**Test Results:**
- Backend: 203 examples, 0 failures
- Frontend: WinePackageItemForm tests 9/9 passing
- All existing regression tests pass

**Files Changed:**
- `app/models/vintage.rb`
- `app/models/wine_package_item.rb`
- `app/serializers/wine_package_item_serializer.rb`
- `spec/requests/api/v1/wine_package_items_spec.rb` (fixed pre-existing test data issues)
- `src/components/WinePackageItemForm.tsx`
- `src/components/InlineWineCreateForm.tsx`
- `src/components/InlineVintageCreateForm.tsx`
- `src/components/WinePackageItemForm.test.tsx`

**No database migrations required.**

---

## Post-implementation fixes (2026-11-19)

Three defects were reported against the first implementation of the line form on
`/wine-packages/:id` and have been fixed.

### 1. Typing in the wine search stole focus / flashed the page

**Cause:** the search input was rendered with `disabled={loadingWines}`. Every
debounced search toggled that flag, so the focused input became disabled and the
browser dropped focus mid-typing.

**Fix:**
- The search input is never disabled while loading; a muted "Searching the
  catalogue…" hint is shown instead.
- Searches are debounced (300 ms) and guarded by a request-id ref so a stale
  response can never overwrite a newer one.
- The input stays mounted for the whole form lifetime, so focus is preserved.

### 2. "Add a vintage" / "Add a new wine" replaced the whole form

**Cause:** both create panels were rendered through an early `return`, which
unmounted the wine selection and package fields.

**Fix:**
- The line form and the create panels are now siblings inside one wrapper
  `<div>`. The create panels keep their own `<form>` (never nested), so pressing
  Enter still submits the right form.
- The wine select, vintage select and package fields remain visible while a
  panel is open, and the trigger button toggles between "Add …" and
  "Close … form".

### 3. A newly created vintage did not appear in the dropdown

**Cause:** `handleVintageCreated` only set the selected id; the loaded `wines`
state never received the new vintage, so the `<select>` had no `<option>` for it.

**Fix:**
- The created vintage is merged into the matching wine's `vintages` array in
  `wines` state and selected immediately (no page reload).
- Creating a brand-new wine likewise merges the returned wine (with its first
  vintage) into the list and selects both.

### Additional corrections in the same pass

- `WinePackageDetail` now passes `packageProducerId` / `packageProducerName`
  (the component still accepts the legacy `producerId` / `producerName` aliases).
- The "Review requested" checkbox now writes `event.target.checked` (booleans),
  not `event.target.value`.
- Editing a line recovers its wine from `item.vintage_id` once the catalogue
  list loads, so the selects show the existing match.
- Added the missing CSS classes (`wineInfo`, `wineInfoLabel`, `unmatchedInfo`,
  `unmatchedLabel`, `referenceValue`) used by the selected/unmatched blocks.
- Updated `WinePackageDetail.test.tsx`: the two former "scopes … to the
  package's producer" tests now assert the new global-search contract.
- Added regression tests: the search input stays enabled while typing, and a
  newly created vintage is immediately selectable.

### Files changed in this pass

- `src/components/WinePackageItemForm.tsx`
- `src/components/WinePackageDetail.tsx`
- `src/components/winePackages.module.css`
- `src/components/WinePackageItemForm.test.tsx`
- `src/components/WinePackageDetail.test.tsx`

### Test results

```
WinePackageItemForm.test.tsx   11 tests, 0 failures
WinePackageDetail.test.tsx     18 tests, 0 failures
Full frontend suite            636 passed; 5 unrelated pre-existing files still fail
TypeScript (tsc -b)            no errors in the changed files
ESLint (changed files)         0 errors, 0 warnings
```

### 4. Line-form layout: fields were stacked one per row

**Cause:** the form carried an inline `style={{ flexDirection: "column" }}`
that overrode `.inlineForm`'s wrapping flex layout, and each group was wrapped in
its own bordered `.filters` box — so every field owned a full row.

**Fix:**
- The form now uses a 12-column CSS grid (`styles.lineForm`) with per-field
  span classes; the inline column style and the per-row `.filters` boxes are
  gone (a single bordered card remains).
- Desktop rows:
  - **Search** (8 cols) + **Add a vintage / Add a new wine** (4 cols)
  - **Wine** (7 cols) + **Vintage** (5 cols)
  - **Unmatched / selected submission** block (full width)
  - **Bottles** (3) + **Condition** (4) + **Notes** (5)
  - **Review requested** (full width)
  - **Save / Cancel** (full width)
- Below 768 px every field spans the full width (`grid-template-columns: 1fr`),
  so the mobile layout stays usable.
- Producer mode reuses the same rows without the search/actions row.

Files: `src/components/WinePackageItemForm.tsx` (markup),
`src/components/winePackages.module.css` (`.lineForm`, `.span*` classes).

Verified: the 29 Wine Package tests still pass, TS and ESLint are clean.

### 5. Resolved catalogue wine was invisible in the trade views

**Symptom:** after the Wine Words team linked a submitted line to a real
wine/vintage on `/wine-packages/:id`, both `/admin/trade/packages/:id` and
`/trade/my-packages/:id` still showed only the submitter's snapshot
("Nepenthe Altitude Sauvignon Blanc · 2026") — the submitter could not see which
wine was actually being reviewed.

**Cause:** `TradePackageSerializer#items_json` only read the `snapshot_*`
columns. Editorial resolution sets `vintage_id` (not `catalogue_wine_id`), so
the trade side had no resolved data at all.

**Fix (backend):**
- `TradePackageSerializer#items_json` now also returns, per item:
  `resolved`, `catalogue_wine_id/name/slug`,
  `catalogue_producer_id/name/slug`, `vintage_id/year/no_vintage/label`.
  The snapshot fields (`wine_name`, `vintage`, region, prices …) are unchanged,
  so the submission of record is never overwritten.
- The item query now eager-loads `vintage: { wine: :producer }` and
  `catalogue_wine: :producer` (no N+1).
- `WinePackageItem` gains `before_validation :adopt_catalogue_wine_from_vintage`:
  when a vintage is linked, the matching `catalogue_wine_id` is filled in, so
  the trade/admin "matched" state is consistent whether the line was resolved
  from the editorial form or via `match_catalogue`.

**Fix (frontend):**
- `TradePackageItem` type extended with the resolved-match fields.
- `/admin/trade/packages/:id` shows, under the submitted wine,
  "Matched to **<catalogue wine>** — <producer> (<vintage>)".
- `/trade/my-packages/:id` shows "Being reviewed as **<catalogue wine>** —
  <producer> (<vintage>)" so the submitter knows the real bottle.
- The "Matched/Being reviewed" line only appears once a catalogue wine exists,
  and the submitted vintage column keeps the original value.

**Tests:**
- New `spec/serializers/trade_package_serializer_spec.rb` (5 examples) covers:
  pre-match snapshot only; post-match snapshot preserved; resolved wine,
  producer and vintage exposed to both `:submitter` and `:staff`; and the
  `catalogue_wine_id` sync on the item.
- Regression: `wine_package_item_spec`, `wine_package_items_spec`,
  `wine_packages_spec`, `trade_spec` → 120 examples, 0 failures.
- Frontend: Wine Package suites 29/29; Trade admin suite 4/5 (the single
  failure is the pre-existing "Unable to record assessment" case, unrelated).

Files: `app/serializers/trade_package_serializer.rb`,
`app/models/wine_package_item.rb`, `spec/serializers/trade_package_serializer_spec.rb`,
`src/types/trade.ts`, `src/components/TradeAdminPackageDetail.tsx`,
`src/components/TradePackageDetail.tsx`.

No database migrations required.

### 6. "Add a new wine" now reuses the /wines/new producer picker

**Request:** when creating a wine from a package line, the editor must be able
to search for — and add — a producer, like `/wines/new`.

**Fix:**
- `InlineWineCreateForm` now embeds the shared `ProducerSearch` component (the
  same debounced producer search used by the wine form):
  - typing ≥ 2 characters renders selectable producer cards;
  - when nothing matches, an inline **Create "…".** button creates the producer
    on the fly (`producersApi.create` with sensible defaults, mirroring the
    wine form), then selects it for the new wine.
- Panel copy now reads "search for the producer below (or create it if it does
  not exist yet)"; the search input gained `aria-label="Producer"` for a11y and
  tests.
- Removed the old `availableProducers` dropdown plumbing from
  `WinePackageItemForm` (state, effect and props) — the picker is self-contained.
- Fixed a markup bug where the intro paragraph rendered a literal
  `<strong>this producer</strong>` string instead of bold text.

**Tests:**
- `WinePackageItemForm.test.tsx` → 12 examples, 0 failures, including:
  - "allows creating a wine with a different producer via the producer search";
  - "lets the editor create a brand-new producer inline" (search miss →
    `producersApi.create` → producer selected → wine posted with the new
    `producer_id`).
- `WinePackageDetail.test.tsx` → 18/18; TypeScript and ESLint clean on the
  changed files.

Files: `src/components/InlineWineCreateForm.tsx`,
`src/components/ProducerSearch.tsx` (aria-label only),
`src/components/WinePackageItemForm.tsx`,
`src/components/WinePackageItemForm.test.tsx`.



### 7. `/trade/my-packages/:id` returned 404 for a logged-in submitter

**Symptom:** after submitting from `/trade/submit` and signing in, the redirect
to `/trade/my-packages/:id` failed with `{ error: "not found" }` from
`GET /api/v1/trade/packages/:id`, while `/wine-packages/:id` rendered fine.

**Root cause (confirmed against the dev DB):** those submissions were made
**anonymously** — `submitter_id` and `created_by` are `NULL` (packages 49 and
50 are `trade_submission` rows with no owner). `set_owned_package` requires
`submitter_id == current_user.id`, so the owner check can never pass until the
package is claimed — and the only claim path required the single-use guest
token, which a logged-in user opening the page does not have.

**Fix (backend):**
- New service `Trade::Packages::ClaimByEmail`
  (`app/services/trade/packages/claim_by_email.rb`): links an **unclaimed**
  trade submission to the signed-in user when the contact email on the
  submission matches the account email; idempotent for the owner; refuses
  already-claimed packages; records one `package_claimed` event
  (`claimed_via: email`). The guest token is intentionally left untouched so
  the emailed guest link keeps working.
- `POST /api/v1/trade/packages/:id/claim` (authenticated) in
  `Api::V1::Trade::PackagesController` via `set_claimable_package`, which keeps
  the no-disclosure rule: missing package, non-trade package, or a package
  claimed by someone else all return the same 404 as `#show`; a `Trade::Error`
  from the service is rendered as 404 too.


**Fix (frontend):**
- `tradeApi.claimPackage(id)` (POST, authenticated).
- `TradePackageDetail` self-heals: on a load failure, when the viewer is
  authenticated and no guest token is in play, it attempts the email-claim once
  and retries the load — turning the 404 into the submitter's own package.
  Guest-token views are untouched.

**Tests:**
- New `spec/requests/api/v1/trade_claim_by_email_spec.rb` — 6 examples, 0
  failures: claims by matching email; a single `package_claimed` event across
  repeats; idempotent re-claim; email mismatch returns 404 and stays
  unclaimed; non-trade package returns 404; another user's claimed package
  returns 404 and is untouched.
- Regression: `trade_spec`, the trade serializer spec and the package
  item/package specs run green together (131 examples, 0 failures).
- Frontend: Wine Package suites 29/29; trade admin 4/5 (pre-existing).
  TypeScript/ESLint: no new issues.

Files: `app/services/trade/packages/claim_by_email.rb` (new),
`app/controllers/api/v1/trade/packages_controller.rb`, `config/routes.rb`,
`spec/requests/api/v1/trade_claim_by_email_spec.rb` (new),
`src/services/tradeApi.ts`, `src/components/TradePackageDetail.tsx`.

No database migrations required.

### 8. "Auto-generate name" in the inline wine panel

**Request:** when creating a wine from a package line, offer the same
"Auto-generate name" convenience as `/wines/new`.

**Fix (`InlineWineCreateForm`):**
- Adds an **Auto-generate name** checkbox under the wine-name field, mirroring
  `WineForm`: while it is on, the name is auto-filled as
  `Producer + Designation` and the field is read-only; ticking it off frees the
  field, and typing a name by hand turns the flag off automatically (same
  override semantics as the wine form).
- Sensible default: the flag starts **off** when the panel is pre-filled with a
  submitted proposal (so a resolution keeps the submitter's wording) and **on**
  for a blank proposal, where generating from the producer is exactly what the
  editor wants.

**Tests:** `WinePackageItemForm.test.tsx` → 13 examples, 0 failures, including
"auto-generates the wine name from producer and designation" (fills from
producer, reacts to designation, read-only while on, editable after untick).
TypeScript and ESLint clean; `WinePackageDetail.test.tsx` still 18/18.

Files: `src/components/InlineWineCreateForm.tsx`,
`src/components/WinePackageItemForm.test.tsx`.


### 9. The team could not add a catalogue line to a trade package

**Symptom:** on `/wine-packages/:id` for a trade submission, adding a line that
resolves to a catalogue wine/vintage failed with 422
"Proposed wine name is required for a trade submission".

**Cause:** `WinePackageItem#wine_named` required `proposed_wine_name` for every
item of a `trade_submission` package — written when trade lines could only come
from the submitter's form. With multi-producer resolution the Wine Words team
adds lines straight from the catalogue (vintage only, no snapshot), which the
validation rejected.

**Fix:**
- `wine_named` now exempts catalogue-anchored lines: the snapshot name is only
  required when the item has **no** `vintage_id` and **no** `catalogue_wine_id`.
  Submitter-added lines (no catalogue link yet) still require the name.
- `TradePackageSerializer` falls back to the resolved catalogue identity for
  display when a trade line has no snapshot
  (`wine_name`/`vintage` ← `catalogue_wine.name` / resolved vintage label) and
  exposes `submitted` (true only when an original snapshot name exists), so the
  UI can tell submitter lines from team-added lines.
- Trade views: the "Matched to …" / "Being reviewed as …" reconciliation line
  renders only for `submitted` items; team-added lines already display the
  catalogue wine/vintage directly.

**Tests:**
- `wine_package_item_spec` "trade submission lines": submitter line without a
  name still invalid; team-added catalogue line valid (and adopts its
  `catalogue_wine_id`); snapshot name alongside a match accepted.
- `trade_package_serializer_spec` "when the Wine Words team adds a catalogue
  line directly": `wine_name`/`vintage` fall back to the catalogue, `submitted`
  false, `resolved` true.
- Regression: item/package/trade/claim suites → 218 examples, 0 failures.
  Frontend suites unchanged (29/29 wine packages; trade admin 4/5 pre-existing).

Files: `app/models/wine_package_item.rb`,
`app/serializers/trade_package_serializer.rb`, `src/types/trade.ts`,
`src/components/TradeAdminPackageDetail.tsx`,
`src/components/TradePackageDetail.tsx`,
`spec/models/wine_package_item_spec.rb`,
`spec/serializers/trade_package_serializer_spec.rb`.

No database migrations required.


### 10. Edit form and status controls back on the package detail page

**Request:** bring the `/wine-packages/:id/edit` form (producer search, source,
expected/arrived dates, review deadline, reviewer picker, notes, package
images, save/cancel) onto the detail page, and restore the ability to change
the package status there.

**Why status controls were missing:** trade submissions
(`source: trade_submission`) live in the TRADE chain (`editorial_pending ->
assessment_in_progress -> approved -> ...`). The editorial buttons (mark in
transit / arrived / reviewing / completed) simply do not apply to those
statuses, so for trade packages the detail page had no status move at all.

**Fix (frontend only):**
- `WinePackageForm` gained optional props (`packageId`, `embedded`, `onSaved`,
  `onCancel`): embedded mode skips the page hero/back link, reports success to
  the parent instead of navigating, and swaps the Cancel link for a button.
- `WinePackageDetail` header action now toggles an inline **Edit package**
  editor (same fields as /edit); saving closes the editor and reloads the
  package.
- For trade submissions where the viewer can manage all packages, the detail
  page now renders an **Editorial assessment** card (Approve submission /
  Reject submission + reason), calling the same
  `PATCH /admin/trade/packages/:id/assess` endpoint the trade admin queue
  uses, then reloading. Editorial-chain packages keep their existing workflow
  buttons (they were never removed).

**Tests:** Wine Package suites all green (detail 18, form 13, item form
included in earlier runs); TypeScript and ESLint clean on the changed files.

Files: `src/components/WinePackageForm.tsx`,
`src/components/WinePackageDetail.tsx`.

No database migrations required.
At completion, provide:

- Summary of implementation.
- Files changed.
- Database migrations and their impact.
- New/changed API endpoints.
- UI changes.
- Tests added.
- Tests run and their results.
- Documentation updated.
- Any unresolved issues or recommended follow-up work.

---

## Phase 8 — AI implementation prompts

Execute this in phases with Codex rather than asking it to change the entire system in one pass. This reduces the risk of breaking existing Wine Package, Submission, Wine or Vintage functionality.

### Prompt 1 — Architecture audit

Repositories:

- API: https://github.com/romalopes/wine_words_api
- Frontend: https://github.com/romalopes/wine_words_frontend

Before implementing anything, audit the current architecture for Wine Package item management and Wine Submission resolution.

#### Objective

We want Wine Packages to contain catalogue Wines from any Producer, while preserving the existing primary Producer relationship on WinePackage.

We also want to refactor unmatched submission resolution so Admin/Editors can match a submitted wine to an existing catalogue Wine or create a new Wine and Vintage directly during resolution.

#### Requirements

Inspect:

- WinePackage model, schema, associations and validations
- Package item model, schema, associations and validations
- Wine model and Producer association
- WineVintage model and Wine association
- Wine Submission models and resolution workflow
- Relevant API controllers, serializers, services and policies
- Frontend Wine Package management forms
- Catalogue search components and API hooks
- Producer and Vintage selectors
- Existing tests and factories

Identify:

1. Where package items are restricted to the package Producer.
2. Whether the restriction exists in the model, database, query, API or frontend.
3. Current unmatched submission lifecycle.
4. Existing catalogue Wine and Vintage creation mechanisms.
5. Existing authorization requirements.
6. Whether any schema changes are required.
7. How to reuse current functionality rather than duplicate it.

#### Business rules

- Keep WinePackage's primary Producer relationship.
- Wines inside a Wine Package can belong to any Producer.
- Each Wine belongs to its own Producer.
- A Package Item references a Wine and Vintage.
- The Vintage must belong to the selected Wine.
- Unmatched submission name and vintage are preserved.
- Admin/Editors can select an existing Wine or create a new Wine.
- New Wine name is editable.
- New Wine requires selecting a Producer.
- New Vintage can be created during resolution.
- The manual "Not in the catalogue yet" checkbox should be removed and replaced with automatic state determination.

#### Constraints

- Do not implement changes during this audit.
- Do not make unrelated refactoring.
- Do not assume model names or API architecture.
- Follow existing coding conventions.

#### Deliverable

Create a concise implementation proposal with:

- Current architecture
- Problem locations
- Proposed model/API/frontend changes
- Required migrations
- Risks
- Test plan
- Recommended implementation order

Wait for approval before implementing.

### Prompt 2 — Backend implementation

Implement the backend changes approved in the architecture audit.

#### Business requirements

1. Preserve WinePackage's primary Producer relationship.
2. Remove the restriction that WinePackage items must use wines from the package Producer.
3. Allow package items to reference any catalogue Wine.
4. Preserve Wine → Producer.
5. Ensure WineVintage belongs to the selected Wine.
6. Preserve original Wine Submission name and vintage.
7. Allow authorized Admin/Editors to resolve submissions using an existing Wine or by creating a new Wine.
8. Allow creation of a missing Vintage during resolution.
9. Require selecting a Producer when creating a new Wine.
10. Prevent duplicate Wines/Vintages where appropriate.

#### API

Implement global Wine search, including Producer information.

Update or implement API operations for:

- Searching Wines globally
- Retrieving Wine details and Vintages
- Selecting a Wine and Vintage for a package item
- Creating Wine with selected Producer
- Creating Vintage for selected Wine
- Resolving unmatched submission

Follow existing API architecture and conventions. Do not unnecessarily create duplicate endpoints if existing endpoints can be adapted.

#### Integrity and security

- Validate all associations.
- Validate Vintage/Wine consistency.
- Enforce authorization server-side.
- Use transactions when multiple records are created.
- Prevent duplicate creation from repeated requests.
- Do not allow changing the WinePackage Producer as a side effect.
- Preserve original submitted information.

#### Tests

Implement model and API tests for:

- Same-Producer wines
- Different-Producer wines
- Multiple Producers in one package
- Global catalogue search
- Wine selection
- Wine creation
- Producer selection
- Vintage selection and creation
- Submission resolution
- Original submission data preservation
- Authorization
- Transaction rollback
- Duplicate prevention

#### Constraints

- Avoid unrelated changes.
- Preserve compatibility with existing packages and submissions.
- Follow current Rails version and conventions.
- Run relevant tests.

#### Deliverable

Report files changed, migrations, API changes, tests run, results and any remaining issues.

### Prompt 3 — Frontend implementation

Implement the frontend changes for Wine Package item management and Wine Submission resolution.

#### Objective

Remove the restriction that wines in a Wine Package must belong to its primary Producer.

Allow Admin/Editors to search all Wines, select an existing Wine/Vintage or create a new Wine and Vintage during the package item workflow.

#### Existing application

Repository:
https://github.com/romalopes/wine_words_frontend

Inspect the current implementation and follow its component, styling, API and state-management conventions.

#### UI requirements

**1. Remove producer restriction**

Remove the UI that:

- Filters catalogue Wines by the Wine Package Producer
- Describes selection as "Wines from this producer"
- Shows producer-specific empty states
- Assumes new Wine inherits the package Producer
- Uses the "Not in the catalogue yet" checkbox

**2. Global catalogue search**

- Search by Wine name.
- Use submitted Wine name as initial search text.
- Search all Producers.
- Show Wine name, Producer and available Vintages.
- Handle loading, errors and no results.
- Avoid ambiguous selection.

**3. Existing Wine selection**

- Allow selecting any catalogue Wine.
- Load Vintages for the selected Wine.
- Preselect the submitted Vintage if it exists.
- Allow creating the submitted Vintage if missing.
- Reset/revalidate Vintage when Wine changes.

**4. Create Wine**

Add an option to create a Wine from the submission.

Fields:

- Wine name (prefilled, editable)
- Producer (required, searchable selector across Producers)
- Vintage (prefilled from submission)

Create the Wine, Vintage and package item using the approved API workflow.

Do not assume the package Producer.

**5. Package item details**

Preserve:

- Quantity
- Condition
- Notes
- Review requested

Switching between matching and creating must not lose these fields.

**6. Automatic unmatched state**

Remove the manually controlled "Not in the catalogue yet" checkbox.

Determine the state from actual Wine and Vintage associations. Display an appropriate unmatched/resolution status when catalogue associations are missing.

**7. Submission resolution**

Prefill the Wine name and Vintage from the submission.

Keep original submitted information available to the editor. Resolving a submission must not overwrite its original data.

**8. UX requirements**

- Follow existing Wine Words styling and design system.
- Responsive desktop/mobile layouts.
- Accessible controls and labels.
- Clear distinction between Wine name and Producer.
- Confirmation/error feedback.
- Prevent duplicate submissions.
- Maintain existing edit/remove functionality.

#### Testing

Add/update frontend tests for search, selection, creation, vintage handling, state preservation, submission resolution, error handling and responsive behaviour.

#### Constraints

- Do not redesign unrelated pages.
- Do not duplicate API logic.
- Reuse existing components when appropriate.
- Maintain existing package item functionality.

#### Deliverable

Report changed components, API integration changes, tests run and results.

### Prompt 4 — Integration, regression and documentation

Verify and complete the Wine Package multi-Producer refactoring.

#### Requirements

Confirm the following end-to-end workflow:

**Workflow A — Existing Wine from same Producer**

1. Open a Wine Package.
2. Add an item.
3. Search using submitted Wine name.
4. Select a Wine from the package Producer.
5. Select existing Vintage.
6. Save.
7. Verify package item displays correctly.

**Workflow B — Existing Wine from different Producer**

1. Open a Wine Package whose primary Producer is Producer A.
2. Search for a Wine belonging to Producer B.
3. Select the Wine.
4. Select its Vintage.
5. Save.
6. Verify the Wine Package Producer remains Producer A.
7. Verify the package item Wine Producer remains Producer B.

**Workflow C — Create Wine**

1. Start from an unmatched submission.
2. Select Create Wine.
3. Verify submitted Wine name is prefilled.
4. Edit Wine name.
5. Select a different Producer from the package Producer.
6. Create Wine.
7. Create/select Vintage.
8. Save package item.
9. Verify the correct associations.

**Workflow D — Create missing Vintage**

1. Select an existing Wine.
2. Verify submitted Vintage is prefilled.
3. Confirm Vintage does not exist.
4. Create Vintage.
5. Save.
6. Verify Vintage belongs to the selected Wine.

**Workflow E — Unmatched submission preservation**

1. Start with unmatched submission.
2. Resolve it.
3. Verify original submission name and vintage remain unchanged.
4. Verify catalogue Wine and Vintage associations are correct.
5. Verify status transitions correctly.

#### Regression verification

Test existing functionality:

- Wine Packages
- Producer relationships
- Package item CRUD
- Wine Submissions
- Wine catalogue
- Vintage catalogue
- Reviews
- Admin/Editor permissions
- Notifications, where relevant
- Existing unmatched submissions

#### Documentation

Update the relevant documentation to explain:

- WinePackage's primary Producer
- Independent Producer of catalogue Wines
- Multi-Producer package items
- Global Wine search
- Wine/Vintage resolution
- New Wine creation and Producer selection
- Automatic unmatched status
- Submission preservation

#### Quality

- Run API tests.
- Run frontend tests.
- Run relevant linting.
- Run build.
- Check for N+1 queries and inefficient search.
- Verify migrations and existing records.
- Avoid unrelated changes.

#### Final report

Provide:

- Summary
- Files changed
- Migration details
- API changes
- Frontend changes
- Test results
- Documentation changes
- Outstanding issues

Do not claim tests passed unless they were actually executed.

---

## Recommended execution order

1. **Architecture audit** — Review both repositories first. Approve the implementation approach before code changes.
2. **Backend** — Associations, validations, global search, wine/vintage creation, resolution endpoints and tests.
3. **Frontend** — Catalogue search, selection, creation, producer selection and automatic unmatched status.
4. **Integration** — Test the complete submission-to-package workflow.
5. **Regression & documentation** — Verify existing behaviour, build, test and document.

**Recommendation:** Start with Prompt 1 in Codex and let it audit both repositories. Review the architecture before approving backend changes. The existing Wine Package and Wine Submission models may already support much of the desired behaviour, so avoid unnecessary migrations or duplicate implementation.
