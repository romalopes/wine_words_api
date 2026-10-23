# Wine Words — Five-Level Taste Parameter Labels

## Objective

Replace the current `TasteParameter` low/high-only descriptive model with five configurable labels for numeric values 1–5, while preserving all existing numeric wine-profile scores and the current frontend scale/slider design.

**Repositories**
- API: https://github.com/romalopes/wine_words_api
- Frontend: https://github.com/romalopes/wine_words_frontend

> This is an implementation plan, not a claim that the current repositories have been inspected or modified. Verify actual model, schema, serializers, seed layout, and component names before editing.

## Proposed labels

| Parameter | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Sweetness | Dry | Off-dry | Medium-dry | Medium-sweet | Sweet |
| Acidity | Low | Medium (-) | Medium | Medium (+) | High |
| Tannin | Low | Medium (-) | Medium | Medium (+) | High |
| Alcohol | Low | Medium (-) | Medium | Medium (+) | High |
| Body | Light | Medium (-) | Medium | Medium (+) | Full |
| Flavour intensity | Light | Medium (-) | Medium | Medium (+) | Pronounced |

Use the existing persisted parameter names/keys (e.g., `flavour` vs `flavour_intensity`) rather than creating duplicates. These labels are practical five-point UI descriptors, not a formal regulatory classification of sweetness or alcohol.

## Design decisions

1. Keep stored numeric scores as integers from 1 to 5 in existing wine-profile/taste associations. Do not convert scores to strings.
2. Name the new columns `label_1`, `label_2`, `label_3`, `label_4`, `label_5`; they describe values rather than store scores.
3. The backend is the single source of truth for labels; React must not hardcode labels per parameter.
4. Keep the current slider, bars, charts, low/high endpoint positioning, and overall UX. Show the current value's descriptive label as well.
5. Seed scripts must be repeatable without creating duplicate parameters or profiles.
6. Safely backfill existing records before removing the old `low`/`high` columns. Audit unknown/custom parameters and preserve their meanings rather than blindly replacing them.
7. Avoid introducing new `TasteParameter` records merely because an existing parameter uses a different spelling/capitalisation.

## Target database schema

Conceptual shape (adapt to the existing schema rather than recreating the table):

```ruby
create_table :taste_parameters do |t|
  t.string :name, null: false
  t.string :label_1, null: false
  t.string :label_2, null: false
  t.string :label_3, null: false
  t.string :label_4, null: false
  t.string :label_5, null: false
  t.timestamps
end
```

Recommended migration sequence:

1. Inspect `db/schema.rb` or `db/structure.sql`, existing `TasteParameter` columns, constraints, and records.
2. Add nullable `label_1`–`label_5` columns.
3. Backfill known parameters with the mapping above; for custom parameters use a reviewed mapping that preserves their original endpoints, or stop for manual review.
4. Verify every existing record has five nonblank labels, with endpoints matching the intended former meanings.
5. Apply `NOT NULL` constraints once verified; consider validation of blank strings in the model.
6. Remove old low/high fields in a separate deployment/migration only after API and frontend consumers have migrated. Use an expand-and-contract rollout if deployments can be staggered.
7. Document a rollback plan and take a production backup before destructive changes.

Example model method:

```ruby
def label_for(value)
  numeric_value = Integer(value, exception: false)
  return nil unless numeric_value && (1..5).cover?(numeric_value)

  public_send("label_#{numeric_value}")
end
```

This method is illustrative; confirm Rails/Ruby version and desired invalid-value behavior. Prefer a stable API contract and explicit validations for score values.

## Seeds

Review **all** `db/seeds/wine_profiles/*.rb` and their loader(s), including any consolidated files, for references to `low`, `high`, parameter labels, profile-score definitions, and `TasteParameter` creation.

- Define the five labels centrally per parameter, then upsert the parameter using its existing unique key.
- Preserve wine profile IDs/associations and their existing 1–5 values.
- Do not copy labels into each wine-profile score record.
- Avoid duplicate seed definitions and duplicate records, especially if multiple files define the same parameter.
- Confirm the loader executes the desired seed file exactly once; rerun the full seed process twice to prove idempotency.
- Ensure newly added taste parameters can specify their own five labels without requiring a frontend release.

Example seed pattern (adjust unique key and actual attribute names):

```ruby
labels = {
  'sweetness' => %w[Dry Off-dry Medium-dry Medium-sweet Sweet],
  'acidity' => ['Low', 'Medium (-)', 'Medium', 'Medium (+)', 'High'],
  'tannin' => ['Low', 'Medium (-)', 'Medium', 'Medium (+)', 'High'],
  'alcohol' => ['Low', 'Medium (-)', 'Medium', 'Medium (+)', 'High'],
  'body' => ['Light', 'Medium (-)', 'Medium', 'Medium (+)', 'Full'],
  'flavour' => ['Light', 'Medium (-)', 'Medium', 'Medium (+)', 'Pronounced']
}

labels.each do |key, names|
  parameter = TasteParameter.find_or_initialize_by(name: key)
  names.each_with_index { |label, i| parameter.public_send("label_#{i + 1}=", label) }
  parameter.save!
end
```

**Important:** The example is not intended to be pasted without checking the existing parameter keys and seed conventions.

## API contract

A parameter may be serialized as:

```json
{
  "id": 1,
  "name": "Acidity",
  "labels": {
    "1": "Low",
    "2": "Medium (-)",
    "3": "Medium",
    "4": "Medium (+)",
    "5": "High"
  }
}
```

The numeric wine profile score remains unchanged (e.g., `acidity: 4`), and the client resolves that score to `Medium (+)`. Decide whether to expose `label_1`–`label_5` directly or a nested `labels` object; prefer compatibility with existing API conventions. Update read serializers, permitted write parameters, API tests, and docs. If both forms are temporarily exposed, document their deprecation timeline.

## Frontend behavior

- Preserve existing visual scales and slider values 1–5.
- Display left endpoint `label_1` and right endpoint `label_5` where the old low/high labels were shown.
- Display the active value's descriptive label, e.g., `4 / 5 — Medium (+)`.
- Use the same mapping in editable and read-only views, profile lists, details, comparisons, and charts where relevant.
- Handle missing or legacy API labels safely during deployment (fallback to numeric score, not a misleading hardcoded label).
- Keep accessible slider labels and keyboard interactions; consider screen-reader announcements of selected descriptive values.
- Preserve existing responsive layout and test narrow screens.

## Phased execution and AI prompts

### Phase 0 — Repository discovery and dependency audit

**AI prompt:**

> Inspect the Wine Words Rails API and React frontend repositories. Find the `TasteParameter` schema/model, all references to its `low` and `high` fields, wine profile score storage, serializers, endpoints, `db/seeds/wine_profiles/*.rb` files and loaders, and React components that render or edit these values. Report exact paths, actual parameter keys, and any deployment compatibility risks. Do not modify code yet. Identify duplicate seed definitions and whether there is a consolidated seed file.

**Acceptance:** File-level inventory, confirmed data model, and agreed API shape.

### Phase 1 — Migration and model

**AI prompt:**

> Implement an additive Rails migration introducing `label_1` through `label_5` on `taste_parameters`. Do not drop existing columns yet. Add model validations and a safe `label_for(value)` method accepting only integer scores 1–5. Create a deterministic, reviewable data backfill for the six known parameters using the agreed mapping. Preserve all existing records and associations. Identify any custom parameters needing explicit mapping. Add model and migration tests. Follow the project's Rails version and conventions.

**Acceptance:** Existing records remain intact; all mapped parameters have five labels; tests pass.

### Phase 2 — Seed refactor

**AI prompt:**

> Update every relevant file in `db/seeds/wine_profiles/*.rb` and its loader to use the five label fields. Keep numeric wine-profile scores exactly as they are. Centralize parameter label definitions, reuse existing parameter keys, eliminate conflicting/duplicate definitions, and make all seed operations idempotent. Verify repeated seed runs do not change record counts or existing score values. Document any seed files made obsolete.

**Acceptance:** Running seeds twice produces no duplicates; scores unchanged.

### Phase 3 — API changes

**AI prompt:**

> Extend the existing TasteParameter API serializers/controllers to expose labels 1–5, respecting current API naming and versioning conventions. Ensure clients can resolve a numeric score to its descriptive label. Update permitted attributes where parameters are editable, API docs, and request/serializer tests. Preserve compatibility with deployed frontend versions until the frontend migration is complete.

**Acceptance:** API provides correct labels for each score and existing consumers remain functional.

### Phase 4 — React changes

**AI prompt:**

> Find every React component that displays or edits wine taste parameters. Preserve the existing low/high endpoint UI and the 1–5 slider, but derive endpoints from `label_1` and `label_5` (or the agreed API `labels` object). Show the descriptive label for the current value and update it live on slider changes. Reuse a single shared mapping/formatting helper; do not hardcode per-parameter labels in React. Handle transitional API responses safely, preserve accessibility and responsive behavior, and add component tests.

**Acceptance:** Numeric values and current UI behavior remain; labels show correctly in all relevant views.

### Phase 5 — Integration, QA, and release

**AI prompt:**

> Run backend and frontend test suites and inspect the full diff for accidental score changes or duplicate seed data. Test all six taste parameters at values 1, 2, 3, 4, and 5, including editor, detail, and comparison screens. Verify seeded and existing database records, old-client compatibility, mobile layout, and accessibility. Provide a deployment checklist for the Rails API and Cloudflare frontend, with an expand-and-contract rollout and rollback strategy. Only after verifying that no code consumes `low`/`high`, prepare the final migration to drop those obsolete columns.

**Acceptance:** All tests pass; rollout and rollback are documented; no loss of historical data.

## Suggested manual commands (adjust to repository conventions)

```bash
# API
bundle exec rails db:migrate
bundle exec rails db:seed
bundle exec rails test    # or the project's RSpec command

# Frontend
npm ci
npm run build
npm test                  # only if the project defines this script
```

Before production migration, back up the PostgreSQL database and review the generated migration SQL. Do not execute destructive migrations on production before checking active frontend and API consumers.

## Definition of done

- [x] All existing parameters have correct five-level labels.
- [x] All existing wine profile numeric scores remain unchanged.
- [x] Seed files are consistent, centralized, and idempotent.
- [x] API exposes labels and passes tests.
- [x] Frontend preserves low/high endpoint presentation and displays selected-value labels.
- [x] No active `low`/`high` column consumers remain before columns are removed.
- [x] Rollout and rollback steps are documented.

---

## Implementation record — October 23, 2026

This section records the implementation performed against the local API checkout at
`/Users/romalopes/Documents/studies/my_project/wine_project/wine_words_api` and the
frontend checkout at `/Users/romalopes/Documents/studies/my_project/wine_project/wine_words`.

### Confirmed repository facts and deviations

- The existing table uses `slug` and `label`; it has no `name` column. The implementation retains those actual fields.
- The active persisted sixth parameter is `fruit` (`Fruit intensity`), not `flavour`. The consolidated seed had a stale `flavour` definition. It was corrected to `fruit`; no duplicate parameter was created.
- The six actual parameter slugs are `acidity`, `alcohol`, `body`, `fruit`, `sweetness`, and `tannin`.
- `app/views/test_parameters/*` and `TestParametersController` refer to a non-existent `TestParameter` model. They are pre-existing dead code and were not activated or changed as part of this feature.
- `low` and `high` database columns were removed after migration. The versioned JSON API deliberately still emits `low` and `high`, derived from `label_1` and `label_5`, to protect older frontend clients during rollout.

### Phase 0 — Repository discovery and dependency audit

**Status:** Complete.

Confirmed the `TasteParameter` model, join score models, serializers, v1 API endpoint, web finder/quiz, Rails views, React form/detail/quiz components, static finder data, all seed sources, and request/model specs. The current numeric score scale was already `1..5`; no score conversion was required.

### Phase 1 — Migration and model

**Status:** Complete.

Added:

- `db/migrate/20261023160000_add_five_level_labels_to_taste_parameters.rb`
- `TasteParameter::LABEL_LEVELS`
- presence validation for `label_1` through `label_5`
- `TasteParameter#label_for(value)` for valid integer values `1..5`
- `TasteParameter#labels` returning the stable JSON shape `{ "1" => ..., ..., "5" => ... }`

The migration backfilled the canonical six slugs with the agreed labels. For any custom row, it preserves former endpoint values where available and supplies explicit intermediate labels before applying `NOT NULL` constraints.

Migrations were applied successfully in development and test:

```bash
bundle exec rails db:migrate
RAILS_ENV=test bundle exec rails db:migrate
```

### Phase 2 — Seed refactor

**Status:** Complete.

Changed:

- `db/seeds/wine_profiles/wine_profiles_seed_consolidated.rb`
- `db/seeds.rb`

The consolidated seed is now the only top-level seed authority. It uses `find_or_initialize_by(slug:)`, contains the five labels centrally, uses the real `fruit` slug, and retains every existing numeric profile score.

Verified two consecutive seed runs with identical counts:

```text
before=6:161:954
after_one=6:161:954
after_two=6:161:954
```

The values are `TasteParameter:WineProfile:WineProfileTasteParameter`; all 954 persisted profile scores remained in the valid `1..5` range.

### Phase 3 — API, web views, and server-rendered quiz

**Status:** Complete.

Changed:

- `app/serializers/taste_parameter_serializer.rb`
- `app/controllers/api/v1/taste_parameters_controller.rb`
- `app/controllers/taste_parameters_controller.rb`
- `app/helpers/taste_parameters_helper.rb`
- `app/views/taste_parameters/{_form,index,show}.html.erb`
- `app/views/web/{finder,quiz}/index.html.erb`
- `app/javascript/controllers/quiz_controller.js`

The API now returns `labels`, while compatibility fields `low` and `high` are derived at serialization time. Editable parameter forms accept all five labels. The server-rendered finder and quiz show level-1/level-5 endpoints and an active descriptive label.

### Phase 4 — React application

**Status:** Complete.

Changed:

- `src/types/catalog.ts`
- `src/utils/tasteParameters.ts`
- `src/utils/tasteParameters.test.ts`
- `src/components/TasteParameterSliders.tsx`
- `src/components/Quiz.tsx`
- `src/components/WineDetail.tsx`
- `src/components/WineProfileDetail.tsx`

The shared helper resolves endpoints and score descriptions from API-supplied labels. Editable sliders and API-driven quiz/detail views now present values such as `4 / 5 — Medium (+)` without hardcoding parameter-specific labels in React. The static Home finder remains separate because it deliberately consumes bundled `src/data/wineData.ts`, not the API catalogue.

### Phase 5 — Contract migration, QA, and release

**Status:** Complete locally.

Added and applied:

- `db/migrate/20261023170000_remove_legacy_endpoints_from_taste_parameters.rb`

This migration dropped physical `low` and `high` columns in both development and test databases. Its rollback recreates them and restores values from `label_1`/`label_5`; it cannot recover any independent historical endpoint wording after a production rollback, so a database backup remains mandatory before production execution.

Validation completed:

```bash
# Rails focused model, API, wine and web-page coverage
bundle exec rspec spec/models/taste_parameter_spec.rb \
  spec/requests/api/v1/taste_parameters_spec.rb \
  spec/requests/api/v1/wines_spec.rb \
  spec/requests/api/v1/wine_profiles_spec.rb \
  spec/requests/web_spa_pages_spec.rb
# 102 examples, 0 failures

# React feature test
npx vitest run src/utils/tasteParameters.test.ts
# 1 test, passing

# Production bundle
npm run build
# passed
```

`npm run typecheck` now reports no taste-parameter errors. It still fails on three unrelated pre-existing `src/components/UserDetail.tsx` errors: unused `useRef`, unused `setRolesLoading`, and `country?.name` on a `string`-typed field. The Vite production build also retains its pre-existing Sentry named-export warning and large-chunk warning, but exits successfully.

Full-suite status was also checked after the feature-specific validation. `bundle exec rspec` currently reports `1381 examples, 43 failures, 2 pending`; its failures are in unrelated mailer, billing, log, wine, article, producer, registration, subscription, Stripe, and Sentry coverage. `npx vitest run` currently reports `63` files with `360` passing and `3` failing tests; all three failures are existing `ApiHealth.test.tsx` backend-version expectations. Neither full-suite run reported a taste-parameter failure.

### Deployment checklist and rollback

1. Back up the production PostgreSQL database before deploying the destructive migration.
2. Deploy the API migration/model/serializer first. The serializer emits both `labels` and derived `low`/`high`, allowing existing frontend releases to continue operating.
3. Deploy the frontend after confirming `GET /api/v1/taste_parameters` returns complete `labels` maps for all six parameters.
4. Smoke-test values 1–5 for all six parameters in wine and wine-profile forms, details, quiz, finder, and mobile layouts.
5. Monitor API validation errors and client exceptions after release.
6. Roll back application code first if needed. To restore physical endpoint columns, run the down migration only after restoring/backing up data; the down migration reconstructs endpoints from levels 1 and 5.
