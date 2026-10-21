# Issue #185 — Implementation Report: Article and Review Deadlines

Source issue: <https://github.com/romalopes/wine_words_api/issues/185>
Plan: `Wine_Words_Issue_185_Deadline_Implementation_Plan.md` (this directory)
Implemented: 2026-10-21

## 1. Summary

Publication deadlines are now first-class on **Articles** and **Reviews**:

- a nullable `date` column on each table;
- a 14-calendar-day default on creation when no explicit value is supplied;
- Reviews inherit a WinePackage deadline when created from a package;
- `overdue` is true only for **drafts** whose deadline is earlier than today;
- published/archived records keep the date but are never flagged;
- deadline input on both React forms and both server-rendered forms;
- deadline badges on the article/review tables, detail pages and Rails lists;
- `deadline`, `overdue` and `days_until_deadline` in every relevant JSON payload.

## 2. Confirmed product decisions

| # | Question | Decision applied |
|---|---|---|
| 1 | Should Articles default to 14 days? | **Yes** — same fallback as standalone Reviews |
| 2 | WinePackage vs Article priority | **WinePackage wins** |
| 3 | Backfill legacy drafts? | **No** — legacy rows keep a null deadline ("No deadline") |
| 4 | Overdue filtering/sorting | **Deferred** to the separate Settings list-management issue |
| 5 | Editable after publication? | **Yes** — the date is retained and editable, but no longer operational |

## 3. Phase 0 — Audit findings

- `articles` and `reviews` had **no** deadline column; `wine_packages.review_deadline`
  and `article_projects.deadline` are nullable `date` columns — the conventions reused.
- `WinePackage` already implements the exact semantics needed (`overdue?` excludes
  terminal statuses, `days_until_deadline` returns negative days). The new
  `Deadlineable` concern mirrors that shape for draft/published/archived.
- Review creation paths found:
  1. `ReviewsController#create` (server-rendered form);
  2. `Api::V1::ReviewsController#create` (React form);
  3. `WinePackages::CreateReviewFromPackage` (service, package items);
  4. `Api::V1::ArticleProjectNotebooksController#create_review` (notebook copy).
- **There is no "create a Review from an Article" path.** Articles link to
  already-published reviews through `ArticlesController#add_review` /
  `link_reviews`. The Article-inheritance rule is therefore implemented as a
  resolver (`Review#inherited_deadline`) and covered by specs, but no current
  creation flow can trigger it. This is documented rather than invented.
- Authorization is unchanged: owner, Editor, Reviewer or Admin, via the existing
  `ensure_author!` / `deny_unless_review_manager!` / `wine_manager?` checks.

## 4. Phase 1 — Database and model

### Migrations (reversible)
- `db/migrate/20261021071641_add_deadline_to_articles.rb` — `add_column :articles, :deadline, :date`
- `db/migrate/20261021071642_add_deadline_to_reviews.rb` — `add_column :reviews, :deadline, :date`

No index: filtering/sorting by deadline is deferred (decision #4), so there is no
query to support yet. No backfill (decision #3).

### `app/models/concerns/deadlineable.rb` (new)
- `DEFAULT_DEADLINE_DAYS = 14`.
- `before_validation :apply_default_deadline, if: :new_record?` → `deadline ||= Date.current + 14`.
  Runs only on create, so updates and bulk changes never reset a deadline.
- `overdue?` → `status == "draft" && deadline.present? && deadline < Date.current`.
  A deadline of today is "due today", not overdue. Uses `Date.current`, i.e. the
  application timezone, never the browser's.
- `days_until_deadline` → signed integer, `nil` when there is no deadline.

### `Article` / `Review`
- Both `include Deadlineable`.
- `Review` gained `has_many :article_reviews` / `has_many :articles, through:`
  (the reverse of the existing join) plus:
  - `inherited_deadline` → `wine_package_deadline || article_deadline`;
  - `wine_package_deadline` → earliest `review_deadline` across fulfilled packages;
  - `article_deadline` → first linked article deadline.

### `WinePackages::CreateReviewFromPackage`
Before saving, `review.deadline` is set from `item.wine_package.review_deadline`
when the caller supplied none. This gives the confirmed precedence
**explicit > WinePackage > 14-day fallback** and copies the date once, at creation.

## 5. Phase 2 — API and authorization

- `ArticlesController#article_params`, `ReviewsController#review_params`,
  `Api::V1::ArticlesController#article_params` and
  `Api::V1::ReviewsController#review_params` now permit `:deadline`.
- `ArticleSerializer`, `ArticleListSerializer`, `ReviewSerializer` and
  `ReviewListSerializer` expose `deadline` (`YYYY-MM-DD`), `overdue` and
  `days_until_deadline`, matching `WinePackageSerializer`.
- List and detail endpoints call the same `overdue?` predicate, so they cannot
  disagree.
- No new policy. A user who cannot edit the record cannot edit its deadline:
  the API still returns `403` for an unrelated user (covered by specs).
- Backward compatible: omitting `deadline` yields the 14-day default; the field
  is additive to every payload.

## 6. Phase 3 — Server-rendered editor forms (Rails/ERB)

- `app/views/articles/_form.html.erb` and `app/views/reviews/_form.html.erb`:
  new `date_field :deadline` with a contextual note. Editing shows the current
  state ("Currently Due 21 Oct 2026"); creating explains the 14-day default.
- `app/views/layouts/application.html.erb`: `.deadline-badge` styles (upcoming,
  today, overdue) and `.deadline-field-note`.
- `app/helpers/deadlines_helper.rb` (new):
  - `deadline_label(record)` → "Due 21 Oct 2026" / "Due today" /
    "Overdue by N days" / "No deadline";
  - `deadline_state(record)` → upcoming / today / overdue / none;
  - `deadline_badge(record)` → renders nothing unless the record is a draft;
  - `deadline_icon(state)` → decorative, `aria-hidden`, so text carries meaning.

## 7. Phase 4 — List and detail UX

### React (`wine_words`)
- `src/components/DeadlineBadge.tsx` (new): the single deadline badge used by
  tables and detail pages. It renders nothing for published/archived records and
  prefers the API's `overdue` / `days_until_deadline` over a client date
  comparison, so it cannot contradict the server.
- `ArticleTable.tsx` / `ReviewTable.tsx`: new **Deadline** column.
- `ArticleDetail.tsx` / `ReviewDetail.tsx`: badge in the byline next to Draft.
- `ArticleForm.tsx` / `ReviewForm.tsx`: `date` input, included in the JSON
  payload (and the article `FormData` path). Values are date-only
  (`YYYY-MM-DD`), so no timezone shift occurs.
- `src/types/article.ts`, `src/types/review.ts`, `src/types/api.ts`:
  `deadline`, `overdue`, `days_until_deadline` added to models and write payloads.
- `src/index.css`: badge styles.

### Rails lists
- `articles/index.html.erb`, `reviews/index.html.erb`,
  `articles/show.html.erb`, `reviews/show.html.erb` render `deadline_badge`.
  Drafts only; published/archived stay uncluttered.

No overdue filter or deadline sorting was added (decision #4).

## 8. Phase 5 — Tests and results

### Backend (RSpec) — executed
```
bundle exec rspec spec/models/deadlineable_spec.rb spec/requests/api/v1/deadlines_spec.rb spec/requests/web_deadlines_spec.rb
32 examples, 0 failures
```
Coverage:
- Article: default, explicit override, legacy null, overdue boundaries
  (yesterday/today/tomorrow), published/archived never overdue,
  draft→published clears the flag but keeps the date, signed day counts,
  update does not reset the deadline.
- Review: standalone default, explicit override, WinePackage inheritance,
  explicit-over-package, package without a deadline, Article resolution,
  WinePackage priority when both are attached, no cascade when the source
  changes, draft-only overdue.
- Serializers: `deadline` ISO string, `overdue`, `days_until_deadline`.
- API requests: backward-compatible default, explicit persistence, owner may
  change, unrelated user gets `403` and the date is unchanged.
- Web rendering (`spec/requests/web_deadlines_spec.rb`): the article and review
  indexes render overdue badges for drafts, published content renders none, and
  both create forms expose the deadline input.

`Date.current` is frozen with `travel_to(Time.zone.local(2026, 10, 21))` so the
timezone-sensitive boundaries are deterministic.

### Full backend suite — executed
```
bundle exec rspec
1345 examples, 57 failures, 2 pending
```
The 57 failures are **pre-existing/environmental** and live entirely outside
this change (mail sender defaults, `401` responses in taste-parameter /
wine-profile request specs, missing seeded records, Sentry context, and
version/config drift). No failure mentions `deadline`, Article or Review; the
new specs pass. `grep -i deadline` over the run log returns nothing.

### Frontend — executed
```
npx tsc -b --noEmit        # clean (see note below)
npx eslint <changed files>  # clean
npx vitest run              # 344 passed, 3 failed (58 files)
```
The three failures are pre-existing:
- `Reviews.test.tsx` expects a "Drink …" window on a list card that does not
  render one (the text exists only in `WineDetail` / `ReviewDetail`).
- two `ApiHealth.test.tsx` cases expect backend version `0.0.20` while the
  workspace reports `0.0.21` — version/config drift.

`src/components/DeadlineBadge.test.tsx` adds 6 passing cases: no deadline,
published, archived, upcoming, due today, overdue count, and "API wins over the
client clock".

> **Type-check gotcha.** The root `tsconfig.json` uses project references with
> `"files": []`, so a bare `tsc --noEmit` checks **nothing** and always exits 0.
> The real command is `tsc -b --noEmit` (this is now what the `type-check`
> npm script runs). The project also compiles with
> `exactOptionalPropertyTypes: true`, which is why `DeadlineBadgeProps` spells
> its optional props as `?: T | null | undefined` — callers pass optional API
> fields straight through, so an explicitly-`undefined` value must be allowed.

### Ruby style — executed
`bundle exec rubocop` on the new/modified files: the new concern, helper and
specs are clean. Remaining offenses in touched files are pre-existing style
rules (e.g. array-bracket spacing) that the repository already violates.

## 9. Deployment and rollback

- Ship the backend first: the columns are nullable and every payload change is
  additive, so old clients keep working (they simply ignore the new fields).
- Ship the frontend second.
- Rollback: revert the application code. Do **not** drop `deadline` — the data
  is harmless and dropping it would destroy manually entered dates.
- After deploy, check `rails db:migrate:status` and application logs.

## 10. Residual risks and follow-ups

1. **Overdue filtering/sorting** was deliberately deferred (decision #4). When
   it lands, add an index on `(status, deadline)` for both tables — currently
   there is no query to justify one.
2. **No Article→Review creation path exists**, so Article inheritance is
   available as a resolver but not reachable from a UI. If such a flow is added,
   call `review.inherited_deadline` before save.
3. **Legacy rows stay null** and read as "No deadline" (decision #3). A future
   backfill, if approved, should be a separate migration.
4. The React form leaves the date input blank for new records; the server then
   applies the 14-day default. The field's helper text states this explicitly.
5. Multiple fulfilled packages: the earliest `review_deadline` is inherited.
   This is deterministic and documented; no product objection was raised.
