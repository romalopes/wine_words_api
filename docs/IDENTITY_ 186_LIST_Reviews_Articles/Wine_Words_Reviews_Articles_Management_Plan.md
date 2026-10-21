# Wine Words — Reviews & Articles Management Implementation Plan

**Date:** 2026-10-21
**Repositories:**

- API: https://github.com/romalopes/wine_words_api
- Frontend: https://github.com/romalopes/wine_words_frontend

> Planning document. The repository implementation has not been inspected for this version; coding agents must verify actual model fields, routes, permissions, and conventions before editing.

## 1. Objective

Add two subitems under **Settings** — **Reviews** and **Articles** — with dedicated management pages inspired by the existing **Producers** management list. Support searching, combined filters, sorting, pagination, and permitted lifecycle actions.

### Navigation

```text
Settings
├── Producers (existing)
├── Reviews   (new)
└── Articles  (new)
```

Proposed frontend routes: `/settings/reviews` and `/settings/articles`. Confirm current routing conventions first.

## 2. User stories

1. As an authorized content manager, I can view Reviews or Articles in a searchable, paginated list.
2. As an author, I can filter **My Reviews** or **My Articles**.
3. As a manager, I can filter by **Draft**, **Published**, **Archived**, **Overdue**, **Due Soon**, and **No Deadline**.
4. I can combine filters, for example `Mine + Draft + Overdue`.
5. I can sort by creation date, deadline, last update, publication date, or title.
6. I can open existing edit/detail workflows and perform only actions my role permits.
7. My filter/sort state persists in the URL when navigating back from editing.

## 3. Scope and decisions

### MVP

- Add permission-aware Settings navigation entries.
- Two separate list pages using shared React components.
- Reuse Producers UI patterns (table, toolbar, pagination, loading/empty/error states).
- Backend filtering, sorting, and pagination, performed server-side.
- Search by relevant existing text fields; include wine/vintage on Reviews only if relationships support it.
- Per-row edit/view navigation and status/deadline indicators.
- Responsive layout and accessibility.

### Phase 2 / optional

- Publish/unpublish/archive/restore from list, reusing existing services.
- Bulk selection/actions with authorization and confirmation.
- Saved filters, exports, assignment, and dashboard summaries.

Do not introduce new database columns merely to support a filter if equivalent fields already exist.

## 4. Suggested UI specification

### Shared layout

- Heading: **Manage Reviews** or **Manage Articles**.
- Use ReviewTable and ArticleTable components
- **New Review / New Article** action, shown only if authorized.
- Text search input with debounce.
- Status dropdown: All, Draft, Published, Archived.
- Toggle: My Reviews / My Articles.
- Deadline dropdown: All, Overdue, Due Soon, No Deadline, Has Deadline.
- Sort dropdown with ascending/descending options.
- Clear filters action.
- Results count and server-side pagination.
- Optional deadline counters at top (overdue, due in next seven days).

### Reviews columns

- Title / wine / vintage (according to current schema)
- Author
- Status
- Deadline
- Created at
- Updated at
- Actions

### Articles columns

- Title
- Author
- Status
- Deadline
- Created at
- Updated at
- Published at (if available)
- Actions

Use compact status labels and visually distinguish overdue deadlines. Keep sorting accessible through table headers or explicit controls. On narrow screens use a responsive table or cards.

## 5. Filter semantics

| Filter       | Definition                                                                                                   |
| ------------ | ------------------------------------------------------------------------------------------------------------ |
| Draft        | Current unpublished draft state in existing schema                                                           |
| Published    | Existing published state                                                                                     |
| Archived     | Existing archived state, if supported; otherwise document migration/workflow requirement                     |
| Mine         | Authored/owned by the current authenticated account according to existing ownership model                    |
| Overdue      | Deadline earlier than today **and** not published/archived, unless existing business rules specify otherwise |
| Due Soon     | Deadline today through seven calendar days ahead and not published/archived                                  |
| No Deadline  | Deadline is null                                                                                             |
| Has Deadline | Deadline is not null                                                                                         |

**Date handling:** Choose the application's configured business timezone and define calendar-day boundaries consistently on the server. A deadline equal to today is **not overdue**. Avoid client/server timezone disagreement.

**Sorting:** `created_at asc/desc`, `updated_at asc/desc`, `deadline asc/desc`, `title asc/desc`, and `published_at asc/desc` where supported. Specify null placement for deadline sorting; always add a deterministic tie-breaker (e.g., `id`). Validate sort fields against an allowlist.

**Combined filters:** Status + mine + deadline condition + search are conjunctive. Pagination must be applied after filtering and sorting. Reset page to 1 when filters change.

## 6. API design (illustrative; verify conventions)

Possible management endpoints:

```http
GET /api/.../reviews?status=draft&mine=true&deadline=overdue&search=semillon&sort=deadline&direction=asc&page=1&per_page=25
GET /api/.../articles?status=published&mine=false&sort=created_at&direction=desc&page=1&per_page=25
```

Do not create these exact paths without checking the existing API namespace, authentication and pagination contract. Prefer extending existing index endpoints if doing so does not alter public listing behavior; otherwise add authorized management-specific endpoints.

Return list fields and pagination metadata using the project's current serializer format. Keep counts scoped to the same authorization rules as the rows. Prevent N+1 queries by eager-loading relevant author/wine associations; add indexes only after reviewing query plans and existing indexes.

### Authorization

- Verify current roles and permissions rather than assuming Reviewer/Editor/Admin capabilities.
- Server-side authorization is mandatory; hidden frontend buttons are not security controls.
- Define the distinction between viewing all content, viewing own content, editing, publishing, archiving, and bulk managing.
- Never leak drafts from other users/organizations when unauthorized.

## 7. Implementation phases and AI prompts

### Phase 1 — Audit the repositories

**Tasks**

1. Locate Settings navigation, routes, Producers list, list APIs, query patterns, and tests.
2. Inspect Review/Article models, relationships, status fields, deadline fields, and ownership rules.
3. Inspect current editor pages and publish/archive actions.
4. Document exact files to modify, migration requirements (if any), and compatibility risks.

**AI prompt**

```text
Inspect the current Wine Words frontend and API repositories:
https://github.com/romalopes/wine_words_frontend
https://github.com/romalopes/wine_words_api

Find the Settings navigation, Producers management list, Reviews/Articles models,
controllers, serializers, frontend routes, editors, RBAC rules, deadlines, and tests.
Produce an audit with exact file paths and current field names. Identify reusable
components and existing lifecycle actions. Propose a compatible implementation
contract. Do not change code or invent schema fields in this phase.
```

**Exit criteria:** Current conventions, actual fields, routes and permissions are documented.

### Phase 2 — Backend management listings

**Tasks**

1. Implement authorized listing/query logic for both resources.
2. Add status, mine, deadline, search and sorting parameters.
3. Add pagination metadata and deterministic ordering.
4. Ensure query efficiency and safe parameter validation.
5. Test status/date boundaries, combinations, unauthorized access and pagination.

**AI prompt**

```text
Using the verified Phase 1 audit, implement server-side management listings for
Reviews and Articles in the Rails API. Follow existing routing, serializers,
authentication, authorization, pagination, and query-service conventions.
Support combined filters: status, mine, overdue/due-soon/no-deadline, text search.
Support allowlisted sort fields/directions and deterministic tie-breakers.
Define overdue as an unpublished/unarchived deadline strictly before today's
business-calendar date. Avoid N+1 queries. Add comprehensive request and model
specs. Preserve public endpoints and existing business behavior. Show the files
changed and explain any migration proposed before applying it.
```

**Exit criteria:** API returns correctly scoped, paginated results for every filter combination.

### Phase 3 — Shared frontend components and Settings navigation

**Tasks**

1. Add Reviews and Articles entries under Settings.
2. Build reusable management table/filter toolbar components, borrowing Producers patterns.
3. Implement URL-synchronized filter, sort and page state.
4. Add loading, empty, error and mobile layouts.
5. Enforce permission-aware navigation and actions.

**AI prompt**

```text
Using the existing Producers management UI as the design reference, create shared
React components for content-management lists in Wine Words. Add permission-aware
Settings subitems Reviews and Articles and routes /settings/reviews and
/settings/articles (adjust if routing conventions require). Build a searchable,
filterable, sortable, paginated interface driven by the new management API.
Filters must combine, URL query parameters must preserve state, and changing
filters must reset pagination. Include accessible controls, responsive layouts,
loading/error/empty states, and tests. Reuse existing design components.
```

**Exit criteria:** Both pages render correct data and filters, with consistent Producers styling.

### Phase 4 — Review-specific and Article-specific behavior

**Tasks**

1. Show resource-specific columns and search labels.
2. Link rows to existing edit/detail pages.
3. Show deadline badges and author ownership indicators.
4. Validate differences between Article and Review models.

**AI prompt**

```text
Complete the Reviews and Articles management pages with resource-specific
columns and navigation. Reviews should display wine/vintage when supported by
the schema; Articles should display article-specific fields. Show author,
publication status, deadline, created/updated dates, and permitted actions.
Mark overdue drafts clearly and do not mark published/archived content overdue.
Preserve list URL state when returning from edit pages. Add tests for each page.
```

**Exit criteria:** Resource-specific presentation is accurate and edit links work.

### Phase 5 — Lifecycle actions (after verifying existing workflows)

**Tasks**

1. Reuse existing publish/unpublish/archive/restore services if available.
2. Add row actions and confirmation for destructive/state-changing operations.
3. Refresh list and counts after successful actions.
4. Consider bulk actions as a separate deliverable with per-record authorization.

**AI prompt**

```text
Audit existing publication and archival workflows for Reviews and Articles.
Reuse established Rails service/controller behavior and authorization policies;
do not duplicate lifecycle logic. Add only supported list row actions such as
publish, unpublish, archive and restore. Confirm state-changing actions and
surface API errors. If bulk actions are approved, implement them separately
with explicit selection, per-record permission checks, partial-failure handling,
and integration tests. Do not silently introduce new statuses.
```

**Exit criteria:** Allowed actions work safely without bypassing existing workflows.

### Phase 6 — QA, performance and documentation

**Tasks**

1. Add backend request tests and frontend unit/integration tests.
2. Add Playwright E2E scenarios if the project already uses Playwright.
3. Test mobile layout, keyboard navigation, permissions, pagination and timezone boundaries.
4. Test larger datasets for query performance.
5. Document final routes, query parameters, permissions and UI behavior.

**AI prompt**

```text
Review the entire Reviews/Articles management implementation. Add automated
coverage for combined filters, Mine, overdue today/yesterday/tomorrow boundaries,
null deadlines, archived/published content, sorting tie-breakers, pagination,
unauthorized users, navigation state, and lifecycle actions. Run the project's
existing lint, tests and build commands. Report failures, performance risks,
changed files, and a manual QA checklist. Update relevant project docs.
```

**Exit criteria:** Tests pass, authorization is verified and documentation reflects the code.

## 8. Acceptance criteria

- [ ] Settings includes Reviews and Articles for authorized users.
- [ ] Both pages match existing Producers management design conventions.
- [ ] Users can search and filter Draft, Published, Archived, Mine, Overdue, Due Soon and No Deadline.
- [ ] Filters combine correctly and results are server-side paginated.
- [ ] Users can sort by creation date and deadline (including direction); optional fields supported where available.
- [ ] Today’s deadline is not overdue; timezone rules are consistent.
- [ ] Published/archived content is not incorrectly counted as overdue.
- [ ] Table columns reflect actual Review and Article data.
- [ ] View/edit navigation works and preserves list context.
- [ ] Backend enforces visibility and action permissions.
- [ ] Empty, loading, error and mobile states are handled.
- [ ] Existing public APIs and editing workflows remain compatible.
- [ ] Automated tests and developer documentation are updated.

## 9. Suggested delivery sequence

1. **PR 1:** Repository audit and agreed API/UI contract.
2. **PR 2:** Backend filters, sorting, pagination and tests.
3. **PR 3:** Shared frontend components, Settings navigation and both list pages.
4. **PR 4:** Lifecycle actions and optional bulk actions.
5. **PR 5:** E2E coverage, optimization and documentation cleanup.

## 10. Open questions for repository audit

- Are Review and Article deadlines already stored on their records or derived from another entity?
- Which publication/archival states exist today?
- Does `Mine` refer to creator, author, assigned reviewer, or another association?
- Should an overdue item that has been published still be shown as historically late? (Recommended MVP: no.)
- Is deadline a calendar date or timestamp, and which timezone governs it?
- Which roles can see all drafts versus only their own?
- Should article and review management include deletion or only archival?

**Recommendation:** Deliver the core lists first, then add lifecycle and bulk actions once existing authorization and state transitions are confirmed.
