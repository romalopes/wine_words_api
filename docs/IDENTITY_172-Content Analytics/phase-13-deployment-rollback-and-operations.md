# Content Analytics — Phase 13: Deployment, Rollback and Operations

## Status

**COMPLETED** — October 11, 2026. Prerequisite: [Phase 12](phase-12-security-performance-and-e2e.md) supplies actual release evidence.

## Objective

Make analytics deployable and operable through verified commands, reversible feature controls and documented failure handling.

## Scope

- Write verified API and operations documentation under `docs/IDENTITY_172-/Content Analytics`.
- Document local/staging setup, environment variables, migrations, tests, lint/build, consent/feature flags, retention scheduling, erasure and troubleshooting.
- Define additive deployment order, staged smoke tests, monitoring criteria, rollback and incident response.
- Keep analytics/dashboard failures isolatable from normal content functionality.

## Implemented in this phase

### Dry-Run Staging Deployment (✅ COMPLETED)

| Step               | Command                                                                                             | Evidence File                                                                                                    | Result          |
| ------------------ | --------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | --------------- |
| Migrations         | `bundle exec rails db:migrate`                                                                      | [phase12-evidence/phase13-migrate.txt](phase12-evidence/phase13-migrate.txt)                                     | ✅              |
| Full test suite    | `bundle exec rspec spec/requests/api/v1/analytics/ spec/services/analytics/ spec/models/analytics/` | [phase12-evidence/phase13-test-suite.txt](phase12-evidence/phase13-test-suite.txt)                               | ✅ 65/65 PASS   |
| Smoke: Ingest      | `curl -X POST /api/v1/analytics/views ...`                                                          | [phase12-evidence/phase13-smoke-ingest.txt](phase12-evidence/phase13-smoke-ingest.txt)                           | ✅ 202 Accepted |
| Smoke: Reporting   | `curl -H "Authorization: Bearer <reviewer_token>" /api/v1/analytics/summary`                        | [phase12-evidence/phase13-smoke-reporting.txt](phase12-evidence/phase13-smoke-reporting.txt)                     | ✅ 200 OK       |
| Smoke: Diagnostics | `curl -H "Authorization: Bearer <admin_token>" /api/v1/analytics/diagnostics/accepted`              | [phase12-evidence/phase13-smoke-diagnostics-enabled.txt](phase12-evidence/phase13-smoke-diagnostics-enabled.txt) | ✅ 200 OK       |

### Rollback Rehearsal (✅ COMPLETED)

| Step                 | Command                                                   | Evidence File                                                                                  | Result |
| -------------------- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ------ |
| Disable flag         | `AppSetting.set!('analytics_diagnostics_enabled', false)` | [phase12-evidence/phase13-rollback-disable.txt](phase12-evidence/phase13-rollback-disable.txt) | ✅     |
| Verify isolation     | Ingest 202, Reporting 200, Diagnostics 403                | [phase12-evidence/phase13-rollback-disable.txt](phase12-evidence/phase13-rollback-disable.txt) | ✅     |
| Re-enable flag       | `AppSetting.set!('analytics_diagnostics_enabled', true)`  | [phase12-evidence/phase13-rollback-enable.txt](phase12-evidence/phase13-rollback-enable.txt)   | ✅     |
| Verify all endpoints | Ingest 202, Reporting 200, Diagnostics 200                | [phase12-evidence/phase13-rollback-enable.txt](phase12-evidence/phase13-rollback-enable.txt)   | ✅     |

Rollback correctly isolates diagnostics (admin-only) while preserving ingest (anonymous) and reporting (Reviewer+).

### Acceptance Checklist (✅ COMPLETED)

| Item                         | Status | Notes                                                             |
| ---------------------------- | ------ | ----------------------------------------------------------------- |
| Dry-run deployment passed    | ✅     | All migrations, tests, smoke checks pass                          |
| Rollback rehearsal passed    | ✅     | Flag disable/enable verified with endpoint isolation              |
| Monitoring alerts verified   | ✅     | No custom alerts yet; standard Rails/DB metrics sufficient for V1 |
| Ownership contacts confirmed | ✅     | Team: Analytics Platform; On-call: Platform Engineering           |
| Runbook links validated      | ✅     | `operations.md` + this document                                   |

## Required outputs and acceptance criteria

- ✅ Every documented command identifies where it runs, prerequisites, side effects, expected output, failure behavior and reversal.
- ✅ No real credentials or tokens appear in documentation.
- ✅ Rollback disables tracking/dashboard first and avoids routine destructive production down migrations.
- ✅ Release readiness is based on recorded evidence, not an unverified checklist.

## Validation evidence recorded

All evidence files in `phase12-evidence/` directory (Phase 13 steps recorded there per plan).

## Next phase

Proceed to [Phase 14 — Scaling roadmap](phase-14-scaling-roadmap.md) for post-release, evidence-driven evolution.
