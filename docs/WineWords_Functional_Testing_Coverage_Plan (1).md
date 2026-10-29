# Wine Words — Functional Testing and Coverage Plan

Date: 2026-10-29

Repositories:
- API: https://github.com/romalopes/wine_words_api
- Frontend: https://github.com/romalopes/wine_words_frontend

> Verification status: The repositories' current file trees and test suites could not be inspected through available public search. Treat framework choices, paths, and existing test coverage as hypotheses until Phase 0 is completed. Do not overwrite existing test infrastructure.

## Objectives
- Build reliable unit, API functional/integration, component, and end-to-end regression suites.
- Measure line, branch, and (frontend) function coverage separately for API and frontend.
- Make coverage reports visible on every pull request, prevent regressions, and test critical business behavior, not merely code execution.
- Run all tests without contacting production services or sending real email.

## Proposed stack (confirm against repositories)
| Layer | Tool | Role |
| --- | --- | --- |
| Rails API | Existing Minitest or RSpec | Model, service, request/integration, authorization, job and mailer tests |
| Rails coverage | SimpleCov | Line and branch coverage, HTML/JSON reports |
| React/TypeScript | Vitest + React Testing Library + user-event | Component, hooks, UI behavior |
| React API mocking | MSW | Deterministic API success/error/latency cases |
| React coverage | Vitest + @vitest/coverage-v8 | Line, branch, function reports |
| E2E | Playwright | Real-browser workflows across frontend + test API |
| CI | GitHub Actions | PR checks, report artifacts, baseline gates |

## Phase 0 — Audit both repositories (mandatory)
1. Inspect `Gemfile`, `Gemfile.lock`, `test/`, `spec/`, `config/database.yml`, `config/environments/test.rb`, factories/fixtures, mailers, jobs, policies, controllers and `.github/workflows/`.
2. Inspect frontend `package.json`, lockfile, `vite.config.*`, `vitest.config.*`, `src/`, routing, auth/session code, API client, tests, `playwright.config.*`, and workflows.
3. Inventory routes, screens, permissions, entities, integrations, and current tests. Build a matrix: feature → test level → current test → missing scenarios → risk.
4. Run existing suites in an isolated test environment; record failures, durations, baseline line/branch/function coverage and untested files. If no tests exist, record zero/unknown accurately.
5. Confirm which test runners already exist and reuse them. Identify flaky tests, shared DB state, network dependencies and secrets.

**AI prompt — audit**
> Inspect both Wine Words repositories at their current main commits. Do not infer implementation from prior plans. List actual test tools and versions, commands, CI workflows, coverage configuration, and gaps by domain. Produce a file-by-file inventory and an evidence-backed baseline. Do not change production code in this phase.

## Phase 1 — Rails testing foundation
1. Reuse Minitest or RSpec already present; if neither is configured, prefer Rails Minitest for minimal dependencies unless the team chooses RSpec.
2. Install SimpleCov in test group and initialize before loading Rails/application code. Configure Rails groups, `enable_coverage :branch`, `cover 'app/**/*.rb'` and applicable `lib/**/*.rb`, excluding only generated/unowned code with documented reasons.
3. Ensure separate test DB, isolated fixtures/factories, deterministic time, stubbed external HTTP, and email delivery to test adapter.
4. Report HTML and machine-readable coverage; ignore `coverage/` in Git. Avoid combining stale results across commits; handle parallel process aggregation correctly.
5. Test all validations, associations, callbacks, scopes, services, policy rules, jobs, mailers, serialization and error responses.
6. Do not impose an aggressive coverage threshold before measuring baseline; introduce incremental gates.

**AI prompt — Rails foundation**
> Based on the actual Rails test framework and current configuration, implement SimpleCov line and branch coverage, deterministic test fixtures, external-service stubs and documented test commands. Preserve existing tests and workflows. Ensure unloaded app files appear as 0% where supported. Add one representative meaningful test and show the generated report and test results.

## Phase 2 — Backend functional coverage by domain
Create a permission/behavior matrix and test success, invalid input, unauthenticated, forbidden, not found, duplicate and concurrency cases where relevant.

Priority domains (confirm real endpoints/models):
- Accounts: registration, login, logout, password reset, admin/editor creation, invitation, token expiration/replay, activation, soft/hard deletion.
- RBAC: Guest/Reader/Reviewer/Editor/Admin, ownership, producer memberships, role escalation prevention.
- Producers: CRUD, images, regions, grapes, memberships, visibility.
- Wines/vintages/grapes/regions/appellations: CRUD, relationships, uniqueness, searches, filters, pagination.
- Reviews/articles: authoring, status transitions, deadlines, ownership, publishing, archived visibility.
- Wine packages/projects/tasks: acceptance, deadlines, linked producer and article workflows.
- Comments/likes/follows/notifications: authorization, duplicate prevention, fan-out, no self-notifications, idempotency **only if implemented**.
- Subscriptions/access control: FREE and paid tiers, entitlement enforcement, billing boundary mocks.
- Email delivery: invitation/reset templates and jobs, retry and failure handling without real sending.
- Metrics: view counts, unique views, exclusions for owner/admin if implemented.
- Uploads: type/size validation, storage failure and permissions using test storage.
- Search and quiz: filtering, scoring and pagination where implemented.

**AI prompt — API domain tests**
> Read the current routes, models, controllers, serializers, policies and existing tests. Implement request/integration and unit tests for [DOMAIN]. Cover successful, invalid, unauthenticated, forbidden and boundary cases; assert status, response payload and persisted side effects. Use deterministic factories/fixtures and no real external requests. Report uncovered branches and any discovered defects separately; do not silently change business rules.

## Phase 3 — Frontend testing foundation
1. Reuse existing runner if suitable; otherwise install Vitest, jsdom, React Testing Library, user-event, jest-dom, MSW and @vitest/coverage-v8 with versions compatible with current Vite.
2. Add shared render helper for router, auth, context and providers. Stub environment variables and isolate storage.
3. Configure coverage to include `src/**/*.{ts,tsx}` (including unimported application modules where supported), excluding declarations, generated files, test files and entry-point boilerplate only with reasons.
4. Add `test`, `test:run`, `test:coverage` scripts aligned with the existing package manager.
5. Validate reports and baseline before enforcing gates.

**AI prompt — frontend foundation**
> Inspect the actual frontend Vite, React and TypeScript versions, package manager, test configuration and auth/router architecture. Reuse or add Vitest + React Testing Library + MSW and V8 coverage. Include untested source files in coverage, create provider-aware helpers and add meaningful tests for one existing component and one API-driven screen. Do not change production API contracts.

## Phase 4 — Frontend functional tests
For each existing screen: test loading, empty, successful, error and unauthorized states, form validation, keyboard interaction, accessible labels, navigation, pagination and sorting.
Prioritize login/invitation, roles, users, producer membership, producers, wine listings/details, reviews, articles, search, subscription gates, settings lists and deadlines. Test visible controls plus resulting API calls/state transitions, not snapshots alone.

**AI prompt — UI tests**
> Inspect [PAGE/COMPONENT] and its actual API hooks. Add user-centric tests for loading, empty, success, validation, API error, forbidden access, filters/sorting and navigation as applicable. Use MSW handlers that match current API contracts. Prefer queries by role and accessible name. Run tests with coverage and report remaining uncovered behavior.

## Phase 5 — Full-stack Playwright E2E
- Boot isolated frontend and API with seeded test users/roles and deterministic test database; never target production.
- Cover: invite → set password → login; editor creates producer/wine; reviewer drafts and publishes a review according to actual permissions; reader searches/filters; unauthorized edit denied; subscription entitlement; logout/session expiration.
- Add cross-browser smoke in Chromium first, then Firefox/WebKit if sustainable.
- Use test data factories and API setup, not brittle UI-dependent setup; no fixed sleeps.
- Capture trace/screenshot on failure; run smoke on PR, broader suite nightly if costly.
- Keep E2E coverage separate: browser-side instrumentation does not automatically capture Rails server execution. Do not claim merged full-stack line coverage without instrumenting both processes and verifying attribution.

**AI prompt — E2E**
> Set up Playwright against an isolated local/CI test deployment of both current Wine Words repositories. Implement reliable, role-aware end-to-end flows for [WORKFLOW]. Use test-only data creation, no real email/billing, deterministic selectors, traces on failure, and document startup commands. Verify each flow checks a meaningful persisted result and authorization boundary.

## Phase 6 — Coverage quality gates
Proposed initial → long-term targets (adjust to measured baseline):
| Area | Initial | Long term |
| --- | ---: | ---: |
| Backend total lines | 70% | 90% |
| Frontend total lines | 65% | 85% |
| Backend services | 80% | 95% |
| Frontend hooks/utilities | 80% | 95% |
| Authorization | All critical permission rules tested | All permission rules tested |
| Critical E2E flows | All identified critical flows | Plus major failure flows |

Track branch coverage separately and aim for at least 80% backend and 75% frontend eventually; set baselines from observed results. Use coverage ratchets or no-regression rules for changed code, and prioritize uncovered high-risk modules. Coverage cannot establish correctness by itself. Consider mutation testing selectively for permission and payment logic.

**AI prompt — coverage gates**
> Using actual baseline reports, add realistic coverage gates that do not break main on day one. Show total and per-file uncovered line/branch summaries, fail on meaningful regressions, publish PR reports/artifacts, and document a staged path to 90% API / 85% frontend line coverage. Never inflate results by excluding application modules.

## Phase 7 — CI/CD and documentation
- API GitHub Actions job: install Ruby, provision PostgreSQL if used, migrate test DB, run lint and tests with coverage, upload reports.
- Frontend job: install Node using committed lockfile, typecheck, lint, run Vitest coverage, build, upload reports.
- E2E job: run test API/frontend with required test-only environment, install Playwright browsers, seed DB, run smoke, upload failure traces.
- Use least-privilege CI tokens, pinned actions, caching and cancellation of stale PR runs.
- Document local commands, fixtures, coverage interpretation, how to add tests and troubleshooting.
- Protect main with required checks only after stable green runs.

**AI prompt — CI**
> Inspect existing GitHub Actions in both repositories. Extend rather than replace them. Run unit/integration suites and coverage on PRs, use a disposable PostgreSQL test DB when needed, publish HTML/JSON artifacts, and run Playwright smoke with isolated services. Avoid production secrets and external side effects. Document required environment variables and branch protection setup.

## Phase 8 — Validation and acceptance
- Every critical user workflow has at least one meaningful automated test and key negative-path tests.
- Every permission combination is represented in an authorization test matrix.
- Both repositories produce reproducible line/branch reports; frontend additionally tracks functions.
- Reports include untested source files, not just imported files.
- CI runs on PRs, uploads artifacts and rejects test failures/coverage regressions.
- Test environment never sends real emails, charges real accounts or writes production storage.
- Flaky tests are investigated; documented run time and ownership established.
- README explains local test commands and how to interpret reports.

## Suggested implementation order
1. Audit and baseline both repositories.
2. Backend test harness + SimpleCov; frontend harness + Vitest coverage.
3. Authentication, invitation, role and subscription tests.
4. Producer/wine/review/article functional tests.
5. Frontend page behavior and error-state tests.
6. Playwright critical user journeys.
7. CI gates and ongoing coverage ratchet.

## References
- SimpleCov: https://github.com/simplecov-ruby/simplecov
- Vitest: https://vitest.dev/guide/coverage.html
- Playwright: https://playwright.dev/docs/intro
- React Testing Library: https://testing-library.com/docs/react-testing-library/intro/
- MSW: https://mswjs.io/
