# Wine Words — Issue #185: Article and Review Deadlines

Source: https://github.com/romalopes/wine_words_api/issues/185

## Objective
Add editable publication deadlines to Articles and Reviews. Draft content should show deadlines and overdue indicators. Reviews inherit deadlines from associated WinePackages or Articles when created; standalone Reviews default to 14 days after creation. Published content is not overdue.

## Scope and repositories
- Backend: https://github.com/romalopes/wine_words_api
- Frontend: https://github.com/romalopes/wine_words_frontend

**Verification note:** The issue text was inspected, but the current repository implementation has not been audited. AI agents must inspect actual model names, associations, enum values, routes, serializers, authorization, and tests before changing code. Do not assume field names or paths.

## Proposed rules
1. Store `deadline` as nullable PostgreSQL `date` on both Article and Review (confirm WinePackage deadline type and existing conventions before choosing).
2. New Article defaults to creation date + 14 calendar days unless an explicit deadline is supplied. This is a proposed clarification; issue #185 only explicitly requires a 14-day fallback for standalone Reviews.
3. On Review creation, use explicit user-supplied deadline first; otherwise WinePackage deadline if linked and present; otherwise linked Article deadline if present; otherwise creation date + 14 days. WinePackage priority when both links exist is a proposed policy to confirm.
4. Copy the date only at creation. Later source changes do not silently update Review deadlines. Association changes after creation should not silently overwrite manual deadlines.
5. Authorised Reviewer, Editor, or Admin can update a deadline, respecting existing ownership and role rules. Do not broaden permissions.
6. `overdue` means content is currently draft, has a non-null deadline, and deadline is earlier than today's date in the application-configured timezone. A deadline of today is due today, not overdue.
7. Published and archived records retain their dates but have `overdue=false` and no active deadline warning. Existing publication transitions remain unchanged.
8. Existing records may retain null deadlines to avoid invented history; optionally offer a separate, approved backfill. Draft null deadlines should display as 'No deadline'.
9. Do not automatically publish, archive, or send notifications as part of this issue.

## Phase 0 — Inspect and document existing implementation
Inspect models, schema, migrations, status enums, WinePackage deadline, Review↔WinePackage and Review↔Article associations, create/update services, strong params, serializers, authorization, frontend forms, list pages, query caching, and tests. Identify differences from the rules above and record decisions. In particular verify whether an Article has an existing deadline and whether linked Reviews can reference both sources.

**AI prompt:**
> Inspect the current wine_words_api and wine_words_frontend repositories for issue #185. Do not edit code yet. Map Article, Review, WinePackage models and associations, status transitions, authorization, serializers, API endpoints, forms, listing pages and tests. Quote relevant file paths and describe the current deadline type and existing patterns. Identify conflicts with the proposed rules, especially both-linked Reviews, existing drafts, timezone, and ownership permissions. Produce a concise implementation checklist.

## Phase 1 — Database and backend model
- Add deadline columns only if absent, using separate reversible migrations and compatible types.
- Prefer service/model-level creation defaulting that handles API creation and other entry points, without overriding explicitly supplied values.
- Validate deadline format and enforce sensible policy consistent with existing WinePackage validation; do not prohibit overdue drafts or historical deadlines without a requirement.
- Use `Time.zone.today` (or existing application timezone policy), not browser-local assumptions.
- Centralize effective default logic and `overdue?` in an appropriate shared concern/service only if it reduces duplication.
- Avoid callback side effects on ordinary updates and bulk changes.
- Add indexes only when supported by actual filtering/query needs.

**AI prompt:**
> Implement backend database and domain changes for issue #185 following existing Rails conventions. Add Article and Review deadline attributes, explicit-over-inherited precedence, a 14-calendar-day fallback, and draft-only overdue evaluation. Reuse WinePackage deadline semantics. Do not override manually entered deadlines, change deadlines on later updates, or silently backfill existing records. Respect existing model/status names. Write focused tests for every precedence branch, null source deadlines, timezone boundaries, and publication state.

## Phase 2 — API and authorization
- Permit deadline on create/update for authorized roles, following existing policy and ownership checks.
- Include `deadline`, and optionally derived `overdue`/`days_until_deadline`, in Article and Review JSON using established serialization conventions.
- Make status-dependent overdue semantics consistent in detail and list endpoints.
- If current list APIs support filtering/sorting, add `overdue` and deadline sort through safe whitelists. Scope and paginate queries before serialization; avoid N+1 loads.
- Prevent unauthorized changes to deadline and association links; use existing policy checks.
- Preserve backward compatibility for clients that omit deadline.

**AI prompt:**
> Extend the existing Rails API for Article and Review deadlines without inventing endpoints. Locate the real controllers, serializers, query objects and authorization policies. Allow authorized Reviewer/Editor/Admin updates according to existing ownership rules. Return deadline and consistent draft-only overdue state; add overdue filter and deadline sorting only where list infrastructure supports them. Add request/policy tests for authorized and unauthorized actors, pagination, sort direction, and backward-compatible payloads.

## Phase 3 — Frontend editor forms
- Add deadline date inputs to Article and Review creation/edit forms.
- Show suggested inherited deadline on new Review after source selection, without overwriting an explicit user edit.
- If both WinePackage and Article are selected, explain which date was used; use backend as final authority.
- Allow authorized users to change deadline and show validation feedback.
- Display deadline in a readable locale format; send ISO `YYYY-MM-DD` date-only values to API to avoid timezone shifts.
- Show deadline on draft detail pages where appropriate; keep published details uncluttered.

**AI prompt:**
> In wine_words_frontend, inspect actual Article and Review create/edit components, API types and data fetching. Add accessible deadline date controls, use existing form and permission patterns, and display source-derived suggestions for Reviews. Ensure user edits are never silently replaced when associations change. Send date-only ISO values and surface API errors. Keep the existing design system and add component tests.

## Phase 4 — Article and Review list UX
- On `/articles` and `/reviews`, display draft deadline as `Due 21 Oct 2026`, `Due today`, or `Overdue by N days` as appropriate.
- Use a visible text label plus icon/color, not color alone; do not show overdue warnings for published/archived items.
- Add overdue filter and deadline ascending/descending sorting if compatible with current list UI.
- If separate Settings management lists are introduced in another issue, reuse deadline components and filter logic rather than duplicating them.
- Test mobile layouts, empty states, pagination, filtering, and timezone-sensitive dates.

**AI prompt:**
> Update the existing Wine Words `/articles` and `/reviews` listing views to display deadlines for drafts and accessible overdue badges when deadlines are before today. Use the API's overdue definition as the source of truth, preserve existing filters, sorting and pagination, and optionally add overdue filtering and deadline ordering. Ensure published and archived content never shows an active overdue warning. Add UI tests for draft, due-today, overdue, published, archived, and missing deadline states.

## Phase 5 — Tests and acceptance criteria

### Backend tests
- Article default, explicit override, and legacy null deadline.
- Review explicit deadline; WinePackage inheritance; Article inheritance; both associations; absent source dates; standalone fallback.
- Creation vs subsequent update; source deadline edits do not cascade.
- Draft yesterday = overdue; today = not overdue; tomorrow = not overdue.
- Published/archived not overdue; transition draft→published clears overdue flag without deleting date.
- Authorization and validation; serialization; filters/sorting if implemented.

### Frontend tests
- Create/edit forms submit date correctly and show inherited suggestion.
- Explicitly edited date remains intact when selection changes.
- Draft list shows deadline, due-today and overdue labels.
- Published/archived list hides active overdue warning.
- Empty/null dates, loading/errors, keyboard and mobile layouts.

### Manual verification
1. Create standalone Review: deadline defaults to 14 days ahead.
2. Create Review from WinePackage: deadline is copied.
3. Create Review from Article: deadline is copied.
4. Override Review deadline manually: override persists.
5. Modify linked WinePackage/Article: existing Review deadline does not change.
6. Set draft deadline to yesterday: list displays overdue.
7. Publish the draft: warning disappears, stored date remains.
8. Log in as unauthorized user: cannot change deadline.

**AI prompt:**
> Review the complete issue #185 implementation across both repositories. Run relevant Rails and frontend tests, typechecking, linting, and build commands discovered from repository configuration. Check date boundaries, role/ownership security, migration rollback, API backward compatibility, query performance and responsive accessibility. Fix regressions, summarize changed files and commands/results, and report any assumptions requiring product approval. Do not claim tests passed unless executed.

## Suggested execution order
1. Phase 0 audit and confirm policies.
2. Phase 1 migration and model tests.
3. Phase 2 API and authorization tests.
4. Phase 3 editor UI.
5. Phase 4 listing UI.
6. Phase 5 end-to-end verification and rollout.

## Deployment and rollback
- Deploy backward-compatible backend schema/API first, then frontend.
- Keep old clients functional when deadline is absent.
- Do not drop data during rollback; disabling frontend controls and reverting API behavior is safer than dropping deadline columns.
- Check production database migration status and application logs after deploy.

## Open decisions before coding
1. Confirm whether Articles should default to 14 days; issue text only specifies this for standalone Reviews.
2. Confirm WinePackage-vs-Article priority when both are attached.
3. Confirm whether legacy draft records should be backfilled or left null.
4. Confirm whether overdue filtering/sorting belongs in this issue or the separate Settings list-management issue.
5. Confirm whether a manual deadline is editable after publication (it is historically retained but no longer operational).
