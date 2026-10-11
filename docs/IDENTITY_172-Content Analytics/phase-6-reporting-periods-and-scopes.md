# Content Analytics — Phase 6: Reporting Periods and Authorization Scopes

## Status

Planned as of October 11, 2026. Prerequisites: [Phase 1](phase-1-metrics-identity-permissions-privacy.md) and [Phase 5](phase-5-frontend-tracking.md).

## Objective

Provide shared, authorization-first period and resource-set services for every reporting query.

## Scope

- Convert approved period tokens/custom Australia/Sydney dates into validated UTC `[start_at, end_at)` ranges.
- Enforce allowlists and caps for period, range, type, sort, grouping and pagination values.
- Build role-scoped resource relations before any aggregation.
- Carry reporting metadata: effective range, timezone, metric version, available history, completeness and scope label.

## Implemented in this phase

No reporting-period service, authorized analytics scope or reporting metadata serializer has been implemented yet.

## Required outputs and acceptance criteria

- DST and end-boundary behavior is correct.
- Reviewer scope is own Articles/Reviews plus global Wines; Editor scope covers all authorized content; Admin site-wide access is distinct from debug permission.
- Readers and Guests cannot access private analytics.
- Query parameters never interpolate into SQL and a changed author/resource filter cannot disclose unauthorized aggregates.

## Validation evidence to record

Record period-unit tests, DST cases, role/scope request specs, parameter validation tests and API metadata examples.

## Next phase

After common reporting inputs are safe and tested, proceed to [Phase 7 — Reporting aggregations and API](phase-7-reporting-aggregations-and-api.md).