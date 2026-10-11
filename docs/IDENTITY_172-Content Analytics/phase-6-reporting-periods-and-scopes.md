# Content Analytics — Phase 6: Reporting Periods and Authorization Scopes

## Status

**Completed** — October 11, 2026. Prerequisites: [Phase 1](phase-1-metrics-identity-permissions-privacy.md) and [Phase 5](phase-5-frontend-tracking.md).

## Objective

Provide shared, authorization-first period and resource-set services for every reporting query.

## Scope

- Convert approved period tokens/custom Australia/Sydney dates into validated UTC `[start_at, end_at)` ranges.
- Enforce allowlists and caps for period, range, type, sort, grouping and pagination values.
- Build role-scoped resource relations before any aggregation.
- Carry reporting metadata: effective range, timezone, metric version, available history, completeness and scope label.

## Implemented in this phase

### `Analytics::Period` (`app/services/analytics/period.rb`)
- **Preset tokens**: `7d`, `30d` (default), `90d`, `1y`, `all`
- **Custom dates**: `start_date` / `end_date` in `YYYY-MM-DD` (Australia/Sydney timezone)
- **Narrowing**: Custom dates may narrow a preset token
- **History bounds**: Clamps to available data (`history_from` / `history_to` from earliest/latest `accepted` event)
- **Validation errors**: `:invalid_period`, `:invalid_date_range`, `:range_too_long` (max 365 days for custom)
- **Metadata output**: token, start_at/end_at (ISO8601), timezone, `partial_history` flag, `available_history` window, `metric_version: "1.0"`
- **Edge cases**: Empty period detection, DST-safe boundaries (beginning_of_day/end_of_day in Sydney TZ)

### `Analytics::Scope` (`app/services/analytics/scope.rb`)
Role-based visibility matrix:
| Role | Articles | Reviews | Wines | Scope Label |
|------|----------|---------|-------|-------------|
| Admin | All published | All published | All published | "Site-wide" |
| Editor | All published | All published | All published | "All permitted content" |
| Reviewer | Own only | Own only | All published | "Your editorial content + global Wines" |
| Reader / Guest | None | None | None | "No access" |

- Deterministic — no query parameters affect scope; role alone determines visible content
- `reporting_access?` helper returns true for Reviewer/Editor/Admin
- `detail_for(type, id)` — safe single-record lookup within scope (returns nil, not 403, to avoid existence disclosure)

## Validation evidence to record

- Period resolution specs: preset tokens, custom dates, narrowing, history clamping, DST boundaries, validation errors
- Scope specs: role matrix, `reporting_access?`, `detail_for` safety
- All services load and respond to `.call` / `.resolve`

## Next phase

Proceed to [Phase 7 — Reporting Aggregations and API](phase-7-reporting-aggregations-and-api.md).