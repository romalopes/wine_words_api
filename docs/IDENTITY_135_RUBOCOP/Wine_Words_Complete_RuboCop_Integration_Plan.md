# Wine Words — Complete RuboCop Integration Plan

**Date:** 30 October 2026  
**Status:** Implementation plan; not an assertion that changes or tests have been run  
**Target:** [Wine Words Rails API](https://github.com/romalopes/wine_words_api)  
**Related frontend:** [Wine Words frontend](https://github.com/romalopes/wine_words_frontend)

> **Source of truth:** This plan expands the partial plan supplied by the project owner. It has **not** been validated against a live checkout of the current repository. The implementation agent must inspect the current branch, `AGENTS.md`, dependencies and CI before changing anything. File paths and commands below are examples until confirmed. Do not report invented violation counts or passing tests.

## 1. Objectives and principles

Introduce repeatable Ruby style and correctness checks, Rails-specific conventions, RSpec linting where applicable, performance linting, CI enforcement, measured technical-debt reduction, and coding-agent guardrails. Integrate with the broader quality stack without confusing static analysis with runtime testing.

```text
Wine Words Rails API
  ├── RuboCop core
  ├── RuboCop Rails (if compatible)
  ├── RuboCop RSpec (if RSpec is used)
  ├── RuboCop Performance (if compatible)
  ├── RSpec / existing Rails test suite
  ├── SimpleCov (test coverage)
  ├── Brakeman (Rails security)
  ├── bundler-audit (dependency advisories)
  └── GitHub Actions quality gates

Separate frontend pipeline: ESLint, TypeScript, Vitest, Playwright, Lighthouse
Operational observability: Sentry, OpenTelemetry, Grafana
```

**Non-negotiable rules:** Never run an unreviewed mass `rubocop -A`; avoid mixing behavior changes and formatting; preserve API response shapes, authorization, business workflows, DB data, and existing tests; keep rollout PRs small; avoid permanent blanket exclusions; do not weaken CI just to make it green. Static analysis cannot guarantee correct SQL performance or business logic.

## 2. Project-specific risk map

| Area | Special care during lint cleanup |
| --- | --- |
| Wines, vintages, producers, grape/region relationships | Preserve association semantics, callbacks, eager loading and ordering. |
| Reviews, articles, article projects, publishing | Preserve status transitions, deadlines, visibility and notifications. |
| Wine packages, shipments, reviewer workflows | Preserve tracking, mail delivery and deadline logic. |
| Comments, likes, follows and notifications | Preserve polymorphic links, idempotency, async behavior and recipient privacy. |
| Users/accounts, invitations, JWT authentication | Preserve token lifecycle, password handling and authorization. |
| Roles, permissions, producer memberships | Preserve deny/grant precedence, ownership and data scoping. |
| Subscriptions and payments | Preserve entitlements, monetary precision and external callbacks. |
| Seeds, migrations, backfills | **Never run destructive seeds against production.** Do not rewrite historical migrations for style only. |
| Background jobs, email and integrations | Preserve retry behavior, transaction boundaries, and secret redaction. |

## 3. Delivery model and phase gates

Every phase has a **scope**, **commands or artifacts**, **acceptance gate**, and **copy-ready AI prompt**. Commit each phase separately. The implementation agent should stop at the gate, report evidence, and wait for approval before the next phase. Suggested PR groups: (1) audit/configuration, (2) baseline and safe corrections, (3) targeted refactors, (4) CI/security, (5) documentation.

---

## Phase 0 — Safety, branch and baseline preparation

**Actions**
1. Read repository instructions and inspect `git status`, default branch, CI, README and current test commands.
2. Create a dedicated feature branch and capture current commit SHA, Ruby/Bundler versions and `bundle check` results.
3. Confirm local/test database separation; verify no scripts automatically invoke destructive seeds.
4. Identify existing CI requirements and establish a known-good test run (or document pre-existing failures).
5. Record exact commands, elapsed times, and relevant environment constraints.

**Example commands**
```bash
git status --short
git rev-parse HEAD
ruby --version
bundle --version
bundle check
ls .github/workflows 2>/dev/null || true
```

**Gate:** clean or documented worktree, safe test environment, baseline recorded; no application edits.

**AI prompt — Phase 0**
> You are working in `romalopes/wine_words_api`. Read `AGENTS.md`, README and CI first. Without modifying code, record branch/commit, Ruby/Rails/Bundler versions, lockfile state, test commands, CI checks and any destructive database or seed hazards. Confirm the test database is isolated from NeonDB production. Report a safe branch/PR strategy and existing test failures. Stop for approval.

## Phase 1 — Complete codebase audit (from original plan)

**Inspect**
- Ruby, Rails, `Gemfile`, `Gemfile.lock`, development/test dependencies and version constraints.
- Existing `.rubocop.yml`, `.rubocop_todo.yml`, `.standard.yml`, formatters and editor settings.
- RSpec/test framework, `.rspec`, `spec/`, factories, SimpleCov, coverage exclusions.
- GitHub Actions workflows, pre-commit hooks, existing quality/security jobs.
- `app/models`, `controllers`, `services`, `policies`, `serializers`, `jobs`, `mailers`, `helpers`, `lib`, `config`, `spec`, `db`, `bin`.
- Wine Words domain flows from Section 2; special attention to long classes/methods, complexity, duplicated logic, inefficient queries and false positives.
- Existing naming, formatting, test patterns, migration and seed conventions.

**Deliverable:** `docs/quality/rubocop-audit.md` with: (A) environment, (B) tests, (C) existing tooling, (D) recommended gems, (E) configuration, (F) compatibility risks, (G) *measured* violation inventory if runnable, (H) rollout, (I) high-risk code, (J) next steps. Distinguish measured results from estimates.

**Gate:** complete audit and compatibility decision; no production behavior changes.

**AI prompt — Phase 1**
> Audit the Wine Words Rails API for RuboCop integration without installing anything or changing code. Inspect all paths, dependencies, test tooling, CI and domain areas listed in this plan. Evaluate `rubocop`, `rubocop-rails`, `rubocop-rspec`, and `rubocop-performance` separately. Identify compatibility, potential false positives, complexity hot spots, high-risk autocorrections, and existing conventions. Produce `docs/quality/rubocop-audit.md` with evidence and exact file references. Never invent counts or claim checks ran if they did not. Stop for review.

## Phase 2 — Decide lint architecture and policies

**Proposed gems (only after compatibility check)**

| Gem | Purpose | Decision rule |
| --- | --- | --- |
| `rubocop` | Ruby style, lint, metrics | Core requirement |
| `rubocop-rails` | Rails-specific rules | Add if compatible with actual Rails version |
| `rubocop-rspec` | RSpec conventions | Add only if the project uses RSpec |
| `rubocop-performance` | Selected Ruby performance patterns | Add if compatible and useful; not a replacement for profiling |

Check extension loading syntax supported by the **installed versions** (`plugins:` vs legacy `require:`); do not mix formats blindly. Pin compatible versions through `Gemfile.lock`, avoid unnecessary global installs, and keep gems in suitable nonproduction groups. Compare Beach Volleyball Hub lint philosophy but do not copy its configuration without review.

**Decisions to document:** target Ruby version, line length, string quotes, frozen-string policy, metrics thresholds, spec-specific allowances, new-cop policy, migration/seed treatment, TODO expiration and lint scope. Prefer repository-native conventions over wholesale reformatting.

**Gate:** approved policy and dependency matrix, no unresolved incompatible extensions.

**AI prompt — Phase 2**
> Using the Phase 1 audit, propose the smallest compatible RuboCop architecture for Wine Words. Verify exact extension versions and their supported loading syntax, Rails/Ruby/RSpec compatibility, and dependency groups. Draft a documented policy for layout, lint, metrics, migrations, seeds, tests, new cops and exclusions. Compare principles with Beach Volleyball Hub only if its actual config is available. Do not install or rewrite code yet. Stop for approval.

## Phase 3 — Install gems and create minimal configuration

**Actions**
1. Add approved gems to the development/test groups, using the repository's dependency conventions.
2. Run Bundler and commit `Gemfile.lock`.
3. Add a minimal `.rubocop.yml` with explicit extension loading, Ruby target/version detection and justified settings.
4. Use narrow path exclusions for generated/vendor files; do **not** blanket-exclude `app/`, `spec/` or `db/`.
5. Decide whether historical migrations should be excluded from select Rails cops while new migrations remain checked.
6. Run RuboCop in report-only mode and confirm no config errors.

**Example commands**
```bash
bundle install
bundle exec rubocop --version
bundle exec rubocop --show-cops > /tmp/wine-words-rubocop-cops.txt
bundle exec rubocop --format progress
```

**Gate:** reproducible install; config loads; complete initial output captured, regardless of existing offenses.

**AI prompt — Phase 3**
> Implement only the approved RuboCop dependencies and a minimal `.rubocop.yml` in Wine Words. Use extension loading syntax valid for the resolved gem versions. Preserve lockfile reproducibility and existing Ruby style. Do not change application or spec code. Run configuration validation and a full read-only lint pass, record commands/results, and explain any exclusions. Stop for approval.

## Phase 4 — Establish measurable offense baseline

**Actions**
1. Capture machine-readable JSON and human-readable reports, grouped by cop, severity, path and count.
2. Identify auto-correctable vs unsafe or behavior-sensitive offenses.
3. Consider `rubocop --auto-gen-config` **only after reviewing generated exclusions**; generated `.rubocop_todo.yml` is a temporary debt ledger, not a permanent license to ignore code.
4. Record baseline counts per category and a time-boxed reduction target. Do not check in enormous raw reports unless useful; publish CI artifacts instead.
5. Classify high-risk code for separate PRs.

**Example commands**
```bash
mkdir -p tmp/rubocop
bundle exec rubocop --format json --out tmp/rubocop/baseline.json || true
bundle exec rubocop --format simple > tmp/rubocop/baseline.txt || true
# Optional, only with explicit review:
# bundle exec rubocop --auto-gen-config
```

**Gate:** offense inventory and explicit debt policy; baseline has not hidden new offenses inadvertently.

**AI prompt — Phase 4**
> Measure Wine Words RuboCop offenses with the approved configuration. Produce counts by cop/file and classify safe corrections, semantic risks and intentional exceptions. Recommend whether a temporary `.rubocop_todo.yml` is justified; if generating it, review every broad exclusion and document a reduction schedule. Do not autocorrect any source. Record reproducible commands and baseline metrics. Stop for review.

## Phase 5 — Safe automatic corrections, in batches

**Actions**
1. Start with low-risk layout, whitespace, trailing commas, and clear syntax simplifications.
2. Prefer `rubocop -a` on an explicit **small file list or cop list**; do not run `-A` globally.
3. Review diffs manually, especially Ruby parsing/precedence, ActiveRecord scopes and callbacks.
4. Run relevant specs after each batch and the full suite before merging.
5. Separate formatting-only commits from logic changes; revert suspicious corrections.

**Example commands**
```bash
bundle exec rubocop --only Layout/TrailingWhitespace,Layout/TrailingEmptyLines -a
bundle exec rubocop --format simple
git diff --check
git diff --stat
# Run actual repository test command discovered in Phase 0
```

**Gate:** reviewed minimal diffs; targeted tests and full suite unchanged from baseline.

**AI prompt — Phase 5**
> Correct only low-risk RuboCop offenses in Wine Words, in small reviewable batches. Use safe `-a`, never global `-A`. Prioritize layout and unambiguous style. Do not change SQL, callbacks, authentication, authorization, payment/subscription or publishing semantics. After each batch show diff, cop counts, tests run and results. Keep formatting separate from refactoring. Stop at the gate.

## Phase 6 — Manual correctness and style cleanup

**Actions**
- Resolve `Lint/*` and selected `Style/*` offenses individually, prioritizing correctness over aesthetics.
- Review nil handling, shadowed variables, unused assignments, rescue behavior, predicate semantics, and mutable defaults.
- Keep public methods, API payloads, authorization rules and callback order stable.
- Add regression tests **before** changing behavior-sensitive constructs.
- Use targeted cop disables only with a nearby explanation and a review date/issue.

**Gate:** no newly introduced correctness offenses; all behavior-sensitive edits have regression coverage.

**AI prompt — Phase 6**
> Resolve remaining Wine Words Lint and selected Style offenses by risk priority. Inspect each finding in context and distinguish genuine defects from intentional code. Before behavior-sensitive changes, add focused regression specs. Preserve API contracts, query semantics, publication state machines, notification fanout and access controls. Document justified narrow disables; report diff, tests and offense delta. Stop for review.

## Phase 7 — Rails-specific rules and database safety

**Actions**
- Enable reviewed Rails cops incrementally and inspect query-related recommendations against actual schema and indexes.
- Review validations, callbacks, transactions, `update_columns`/`update_all`, `find_each`, time zones, uniqueness and enum conventions.
- Check N+1 risk with query tests/profiling; RuboCop alone cannot prove query efficiency.
- Treat existing migrations as historical artifacts; avoid rewriting executed migrations for style.
- Inspect `db/seeds` for destructive behavior and keep test/CI tasks away from production data.

**Gate:** Rails cops adopted with documented exceptions; DB behavior and migration history preserved.

**AI prompt — Phase 7**
> Enable and address Rails-specific RuboCop cops in Wine Words one group at a time. Inspect ActiveRecord associations, callbacks, transactions, SQL semantics, validations, time zones, serializers and domain workflows. Never modify already-applied migrations merely to satisfy style; never run destructive seeds. Add focused database/request specs for semantic changes and report query/performance evidence separately. Stop for approval.

## Phase 8 — RSpec-specific linting and test quality

**Actions**
- Confirm RSpec is the actual test framework before enabling `rubocop-rspec`.
- Adopt naming, expectation and example-structure cops with practical limits; avoid refactoring tests into unreadable helpers solely to satisfy metrics.
- Preserve fixtures/factories and test isolation; avoid `let!` removal if setup side effects matter.
- Add regression specs for critical Wine Words paths; track coverage with SimpleCov **separately** from RuboCop.
- Document exclusions for generated or unusual test structures.

**Gate:** spec lint is repeatable; tests pass; no loss of meaningful assertions or coverage.

**AI prompt — Phase 8**
> If Wine Words uses RSpec, configure compatible `rubocop-rspec` rules and incrementally clean spec offenses. Preserve assertion intent, setup side effects, mocks and database isolation. Prefer readable tests over arbitrary metrics compliance. Add regression specs for critical authentication, permissions, publication, subscriptions and notifications where cleanup needs them. Run actual RSpec and SimpleCov commands and report evidence. Stop for review.

## Phase 9 — Performance cops and targeted refactors

**Actions**
- Introduce approved `rubocop-performance` cops; validate suggested changes with representative data and benchmarks where warranted.
- Rank metrics offenses (`Metrics/MethodLength`, `AbcSize`, `CyclomaticComplexity`, `ClassLength`) by change frequency, defect risk and domain importance.
- Extract small service objects only where they improve cohesion; avoid creating abstractions solely to silence cops.
- For complex controllers/services, write characterization specs before refactoring; confirm authorization and response contracts.
- Measure DB query count and latency for suspected N+1 issues rather than assuming performance gains.

**Gate:** targeted refactors have before/after evidence; no regressions or unexplained query changes.

**AI prompt — Phase 9**
> Review Wine Words Performance and Metrics offenses, prioritize high-risk or frequently modified code, and propose small cohesive refactors. Add characterization tests before extracting services or changing loops/queries. Validate query counts and benchmarks where relevant. Do not apply speculative micro-optimizations or silence metrics with broad exclusions. Show before/after complexity, tests and performance measurements. Stop for approval.

## Phase 10 — New-code policy and local developer workflow

**Actions**
- Add documented commands to README or `docs/quality/rubocop.md`.
- Offer a local wrapper (`bin/rubocop` or project convention), editor integration and optional pre-commit hook; keep hooks fast and opt-in if burdensome.
- Define policy: new/changed Ruby must pass applicable cops; existing baseline debt may be addressed gradually.
- Document when a cop may be disabled and how to reduce `.rubocop_todo.yml` over time.
- Add guidance to `AGENTS.md` if present and appropriate: run lint and tests, avoid `-A`, report failures truthfully.

**Gate:** contributor instructions reproducible from a fresh checkout.

**AI prompt — Phase 10**
> Document Wine Words RuboCop usage for developers and AI coding agents. Add the verified install/lint/autocorrect commands, safe correction policy, exception rules, and baseline reduction workflow. Update `AGENTS.md` only in line with existing repository conventions. Avoid mandatory heavyweight local hooks. Test the instructions from a clean dependency install where feasible. Stop for review.

## Phase 11 — GitHub Actions RuboCop CI gate

**Actions**
1. Inspect current workflows and reuse Ruby/Bundler setup and cache conventions; avoid duplicate jobs.
2. Add a dedicated lint job with least-privilege permissions and appropriate pull-request/push triggers.
3. Use `bundle exec rubocop --format progress` (or existing wrapper); fail CI on **newly enforced** offenses.
4. If baseline TODO is used, ensure CI applies the same config and prevents newly introduced offenses; track legacy offenses separately.
5. Pin actions appropriately, configure concurrency/timeouts, and optionally upload JSON results as an artifact.
6. Make RuboCop a required branch-protection check only after it is stable; avoid blocking emergency fixes on unrelated historical debt.

**Illustrative job — adapt to existing workflows**
```yaml
name: Ruby lint
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  rubocop:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - name: RuboCop
        run: bundle exec rubocop --format progress
```

**Gate:** PR with deliberate lint offense fails; clean PR passes; no production secrets needed.

**AI prompt — Phase 11**
> Integrate RuboCop into Wine Words GitHub Actions using existing workflow patterns. Keep permissions minimal, dependencies cached, and checks deterministic. Ensure the selected baseline strategy does not permit new violations. Verify CI by demonstrating a clean run and a controlled failing lint example without merging the bad code. Document branch protection and rollback. Do not duplicate existing workflows. Stop for review.

## Phase 12 — Broader backend quality pipeline

**Actions**
- Integrate existing RSpec/test suite, SimpleCov, Brakeman and bundler-audit (correct executable: `bundle-audit`) as distinct checks when compatible.
- Define coverage policy based on observed baseline; prioritize critical branch coverage rather than imposing an arbitrary global threshold immediately.
- Separate static security findings from dependency advisories and runtime monitoring.
- Make jobs parallel where useful, but reuse setup and avoid duplicate expensive checks.
- Keep test credentials isolated; do not run production migrations or seeds from lint jobs.

**Illustrative local commands (verify first)**
```bash
bundle exec rubocop
bundle exec rspec
bundle exec brakeman --no-pager
bundle exec bundle-audit check --update
```

**Gate:** each check has clear ownership, actionable failure messages and reproducible local commands.

**AI prompt — Phase 12**
> Extend Wine Words backend CI beyond RuboCop only after auditing existing checks. Integrate or rationalize RSpec, SimpleCov, Brakeman and bundler-audit without duplicate jobs. Preserve isolated test DB configuration, avoid production credentials and destructive seeds, and document security triage and realistic coverage thresholds. Execute checks and report actual outcomes, versions and timing. Stop for review.

## Phase 13 — Incremental debt reduction and quality dashboard

**Actions**
- Establish a weekly/monthly reduction target based on measured baseline, not an invented count.
- Track offense counts by cop and domain; monitor TODO-file size, lint duration, flaky tests and CI failures.
- Prioritize code touched by feature work and security-sensitive modules.
- Remove obsolete exclusions when offenses are fixed; re-run `rubocop --auto-gen-config` only with careful diff review.
- Consider Dependabot/Renovate for dependency updates, subject to existing project policy.

**Gate:** trend reports show baseline debt shrinking without rising regression rate.

**AI prompt — Phase 13**
> Build a lightweight RuboCop debt reduction process for Wine Words. From measured baseline and current reports, create a prioritized backlog by cop and domain, with owners/effort/risk, target dates and monthly trend metrics. Remove exclusions only when fixed and verified. Avoid introducing a new dashboard service unless existing GitHub Actions artifacts or reports are insufficient. Stop for review.

## Phase 14 — Release readiness and rollback

**Actions**
1. Re-run full lint, specs, coverage and security checks on the exact release commit.
2. Review diff for unintended API/schema/behavior changes; confirm migrations/seeds are untouched unless explicitly needed.
3. Check Render build behavior and Bundler groups: development/test-only lint gems must not become runtime requirements.
4. Verify GitHub required checks, cache behavior and docs.
5. Rollback options: revert offending cleanup PR; temporarily relax only a clearly identified new cop; revert CI gate if it prevents releases, while retaining a follow-up issue. Never hide application defects by globally disabling lint.

**Gate:** signed-off checklist, reproducible green CI (or explicitly documented pre-existing failures), rollback instructions.

**AI prompt — Phase 14**
> Perform a release-readiness review of Wine Words RuboCop integration. Run full lint, tests, coverage and security checks on the release commit. Inspect all changed code for business behavior, migration/seed risks, Render compatibility and dependency-group correctness. Produce a go/no-go report with exact commands, results, unresolved exceptions and a reversible rollback plan. Do not claim a green build without logs. Stop for final approval.

## Phase 15 — Cross-project alignment and frontend follow-up

**Actions**
- Compare final Wine Words and Beach Volleyball Hub configs; standardize principles (not necessarily identical thresholds).
- Document intentional differences by Rails version, RSpec usage and domain architecture.
- Plan a **separate** Wine Words frontend quality initiative: ESLint, TypeScript, Vitest, Playwright and Lighthouse.
- Combine backend/frontend checks at the GitHub PR level without forcing unrelated apps to rerun expensive suites needlessly.
- Keep Sentry/OpenTelemetry/Grafana as observability, not substitutes for static checks.

**Gate:** shared maintenance principles, explicit deviations, separately scoped frontend backlog.

**AI prompt — Phase 15**
> Compare the verified RuboCop setups in Wine Words and Beach Volleyball Hub. Propose common policy and tooling only where compatible, explaining intentional differences. Then outline a separate Wine Words frontend lint/typecheck/test CI plan (ESLint, TypeScript, Vitest, Playwright, Lighthouse) without implementing it. Do not assume access to either repo; report missing evidence. Stop for review.

---

## 4. Suggested implementation order and PR breakdown

| PR | Phases | Scope | Expected risk |
| --- | --- | --- | --- |
| 1 | 0–2 | Audit, policy and decisions | Very low |
| 2 | 3–4 | Dependencies, config, offense baseline | Low |
| 3 | 5–6 | Safe formatting and selected lint fixes | Low–medium |
| 4 | 7–8 | Rails/RSpec-specific corrections | Medium |
| 5 | 9 | Targeted metrics/performance refactors | Medium–high |
| 6 | 10–11 | Docs and GitHub Actions gate | Low–medium |
| 7 | 12 | Security, tests, coverage integration | Medium |
| 8 | 13–15 | Debt management, release review, alignment | Low |


## 5. Acceptance checklist

- [ ] Audit identifies real Ruby/Rails/test versions and existing quality tooling.
- [ ] RuboCop and compatible extensions install reproducibly via Bundler.
- [ ] Configuration is minimal, reviewed, documented and version-compatible.
- [ ] Baseline counts and risk categories are measured and recorded.
- [ ] No global unreviewed unsafe autocorrection was performed.
- [ ] Formatting-only changes are separated from semantic refactors.
- [ ] Critical auth, RBAC, subscriptions, publishing, packages and notifications have regression protection.
- [ ] Historical migrations and production data were not modified for lint compliance.
- [ ] RSpec lint is enabled only if RSpec is actually present.
- [ ] CI fails for newly introduced enforced offenses and passes on verified clean code.
- [ ] Coverage, security scans and RuboCop are distinct, well-documented checks.
- [ ] Agent instructions and developer commands are up to date.
- [ ] Debt baseline shrinks over time and exclusions have owners/rationale.
- [ ] Render deployment remains compatible and lint dependencies are not runtime dependencies.
- [ ] Full final checks and rollback plan are recorded.

## 6. Master AI prompt — orchestrate all phases

> You are the lead Ruby/Rails quality engineer for the Wine Words API (`romalopes/wine_words_api`). Implement the attached **Wine Words — Complete RuboCop Integration Plan** in order, one phase at a time. Start with Phase 0, then audit the current repository before deciding gems/configuration. Read repository instructions and inspect actual versions, existing tests and CI. Never claim access, tests, counts or results you cannot verify. Never run destructive seeds or modify production data. Avoid global `rubocop -A`, blanket exclusions and broad refactors. Preserve Wine Words business rules across wines, vintages, reviews, articles, packages, accounts, roles, subscriptions, publishing and notifications. For each phase: state files inspected/changed, exact commands, observed output, offense delta, test results, risks and acceptance-gate status; then **stop for approval**. Keep commits/PRs small and reversible. Do not move to the next phase automatically.

## 7. Useful reference documentation

- RuboCop: https://docs.rubocop.org/rubocop/
- RuboCop Rails: https://docs.rubocop.org/rubocop-rails/
- RuboCop RSpec: https://docs.rubocop.org/rubocop-rspec/
- RuboCop Performance: https://docs.rubocop.org/rubocop-performance/
- GitHub Actions Ruby: https://docs.github.com/en/actions
- Brakeman: https://brakemanscanner.org/
- bundler-audit: https://github.com/rubysec/bundler-audit

**Recommended repository destination:** `docs/quality/Wine_Words_Complete_RuboCop_Integration_Plan.md`.
