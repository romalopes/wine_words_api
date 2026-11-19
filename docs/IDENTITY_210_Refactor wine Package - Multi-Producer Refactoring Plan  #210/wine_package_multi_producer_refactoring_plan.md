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

## Phase 2 — Backend model refactoring

### 2.1 Preserve Wine Package → Producer

Keep the existing association intact.

```ruby
WinePackage belongs_to :producer
```

This association continues to represent the primary producer of the package. Do not repurpose it or automatically change it when package items are added.

### 2.2 Remove package-item producer restrictions

Review the Wine Package item model and remove validations, scopes, query restrictions or callbacks that enforce:

```ruby
package_item.wine.producer_id == wine_package.producer_id
```

The package item must be able to reference a wine belonging to any Producer.

### 2.3 Preserve Wine → Producer relationship

The catalogue Wine continues to belong to its own Producer:

```ruby
Wine belongs_to :producer
```

This relationship is the source of truth for the wine's producer.

### 2.4 Validate WineVintage

Ensure the selected vintage belongs to the selected wine.

Conceptually:

```ruby
package_item.wine_vintage.wine_id == package_item.wine_id
```

Use the project's existing association and validation conventions rather than introducing duplicate or redundant relationships unnecessarily.

### 2.5 Preserve unmatched submission information

Unmatched submission records must continue to preserve their original data, such as:

- Submitted wine name.
- Submitted vintage.
- Submission details.
- Submitter information.
- Package context.

Resolving the submission must not overwrite the original submitted values.

### Database changes

Only create migrations if the current schema requires them.

Potential work:

- Remove obsolete producer-matching constraints.
- Adjust validations or database constraints if producer equality is enforced.
- Add missing uniqueness constraints for WineVintage, if not already present.
- Add or adjust search indexes if needed.

Avoid unnecessary schema changes if the existing models already support this structure.

---

## Phase 3 — Backend API changes

Implement or adapt API operations required by the new workflow.

### 3.1 Global wine catalogue search

Provide a search endpoint that searches all catalogue wines, not just wines belonging to the package Producer.

Expected capabilities:

- Search by wine name.
- Partial name matching.
- Return Producer information.
- Return wine IDs.
- Return available vintages.
- Support pagination if required.
- Efficient querying without N+1 problems.

Suggested response structure:

```json
{
  "wines": [
    {
      "id": 123,
      "name": "Altitude Sauvignon Blanc",
      "producer": {
        "id": 45,
        "name": "Nepenthe"
      },
      "vintages": [
        {
          "id": 101,
          "year": 2022
        },
        {
          "id": 102,
          "year": 2023
        }
      ]
    }
  ]
}
```

Follow the existing API response conventions. This JSON is illustrative, not a requirement to change all serializers.

### 3.2 Wine lookup

Ensure the frontend can:

- Retrieve a specific wine.
- Retrieve its Producer.
- Retrieve all available vintages.
- Load the selected wine into the package item form.

### 3.3 Wine creation

Allow an authorized Admin/Editor to create a wine with:

- Wine name.
- Producer ID.

The Producer must be selectable from the full list of permitted producers.

The API must not default the new wine's Producer to the package Producer.

### 3.4 Vintage creation

Allow an authorized Admin/Editor to create a vintage for a selected Wine.

- Wine ID.
- Vintage year.
- Existing model-required fields, if any.

Prevent duplicate vintages for the same wine.

### 3.5 Combined resolution operation

Prefer an existing API architecture where possible. If it makes sense within the existing design, implement an atomic operation to resolve a package item by:

1. Selecting an existing wine and vintage.
2. Creating a missing vintage for an existing wine.
3. Creating a new wine and vintage.

This operation should handle the catalogue and package item association consistently and use transactions where multiple records are created.

### 3.6 Authorization

Only Admins and Editors with the appropriate permissions may:

- Resolve submissions.
- Create catalogue wines.
- Create vintages.
- Change package-item wine associations.

Do not rely on the UI hiding actions as a security mechanism.

---

## Phase 4 — Frontend: refactor the Wine Package item form

This is the main UI change.

### 4.1 Remove the old producer-restricted interface

Remove the assumptions and UI logic that:

- Display only wines belonging to the package Producer.
- Say "Wines from this producer".
- Say "This producer has no wines in the catalogue yet".
- Restrict adding new wines to the package Producer.
- Use the manually controlled "Not in the catalogue yet" checkbox to determine catalogue status.

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

The implementation should follow Wine Words' actual component and styling conventions; this outline is not a requirement to reproduce a static mockup.

### 4.3 Catalogue search results

Each result should clearly display:

- Wine name.
- Producer name.
- Vintages available.

This is important because wines can have similar names from different producers.

The search must be global, and the UI must not imply that results are limited to the Wine Package's producer.

### 4.4 Selection behaviour

When the user selects a wine:

1. Set the selected Wine.
2. Load that Wine's vintages.
3. Find the vintage matching the submission.
4. Select it automatically if found.
5. Otherwise offer to create the submitted vintage.
6. Preserve the other form fields.

If the user changes the selected wine, clear or revalidate the selected vintage, because a vintage cannot belong to the previous wine.

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

### 4.6 Form state and validation

Ensure:

- Catalogue selection and creation modes are explicit.
- Switching modes does not lose quantity, condition, notes or review requested.
- Required fields are validated.
- Vintage is required when the workflow requires a vintage.
- Loading, error, success and empty-search states are handled.
- Duplicate submission or rapid double-click cannot create duplicate records.
- The form remains responsive on desktop and mobile.

---

## Phase 5 — Submission resolution workflow

### 5.1 Automatic unmatched status

Replace the manual checkbox.

Old:

```text
☑ Not in the catalogue yet
```

New behaviour:

| Package item state | Status |
|---|---|
| No Wine selected | Not in catalogue yet / Unmatched |
| Wine selected, no Vintage selected | Needs vintage resolution |
| Wine and Vintage selected | Matched |
| Original submission with catalogue resolution | Resolved |

The exact status labels should align with existing Wine Words terminology.

The status must be derived from the actual associations, not a checkbox that can contradict the data.

### 5.2 Pre-fill submission data

When resolving a Wine Submission, initialize the form using:

- Submitted wine name.
- Submitted vintage.
- Submitted quantity.
- Submitted notes, where applicable.

The submission data should remain visible to the editor as reference during matching.

### 5.3 Resolve to an existing wine

The editor can:

- Search the catalogue.
- Select a Wine from any Producer.
- Select the correct Vintage.
- Create the Vintage if missing.
- Save and resolve the submission.

### 5.4 Resolve by creating a wine

The editor can:

- Use the submitted wine name.
- Edit the name.
- Select a Producer.
- Create the Wine.
- Create the Vintage.
- Link it to the package item.
- Resolve the submission.

### 5.5 Preserve traceability

Keep the original submission name and vintage intact.

The catalogue Wine/Vintage is the resolved reference; the original submission is historical source information.

Do not overwrite the submission's original values with the catalogue values.

---

## Phase 6 — Testing strategy

Implement tests across the API and frontend.

### 6.1 Model tests

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
