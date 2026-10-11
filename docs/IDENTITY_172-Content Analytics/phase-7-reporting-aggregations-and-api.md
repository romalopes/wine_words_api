# Content Analytics — Phase 7: Reporting Aggregations and API

## Status

Planned as of October 11, 2026. Prerequisite: [Phase 6](phase-6-reporting-periods-and-scopes.md).

## Objective

Implement bounded SQL reporting services and authorized endpoints without Cartesian multiplication or misleading distinct counts.

## Scope

- Build summary, content-performance, content-detail and trending aggregation services from `ContentView`, Likes and visible Comments/replies.
- Preaggregate each metric before joins; include zero-view authorized content where required.
- Add audited equivalents of summary, content, content-detail and trending reporting endpoints.
- Provide pagination, deterministic sorting, validation and completeness/history metadata.

## Implemented in this phase

No analytics aggregation query, reporting serializer, reporting endpoint or query-performance test has been implemented yet.

## Required outputs and acceptance criteria

- Multiple views/likes/comments do not inflate totals.
- Resource unique viewers and authorized-set unique visitors use their distinct identity definitions.
- Replies are included and separately exposed; mutable surviving Like/Comment history is documented.
- Zero-view interaction rates return `0.0` and a denominator-zero flag; interaction rates may exceed 100%.

## Validation evidence to record

Record query/service specs, authorization request specs, SQL/EXPLAIN results, pagination cases and response examples.

## Next phase

After reporting APIs are stable, proceed to [Phase 8 — Dashboard overview and content tables](phase-8-dashboard-overview-and-content-tables.md).