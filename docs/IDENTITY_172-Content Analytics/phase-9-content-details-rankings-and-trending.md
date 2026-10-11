# Content Analytics — Phase 9: Content Details, Rankings and Trending

## Status

Planned as of October 11, 2026. Prerequisite: [Phase 8](phase-8-dashboard-overview-and-content-tables.md).

## Objective

Extend the dashboard with authorized per-content detail, ranking and trending views while retaining safe scope and metric semantics.

## Scope

- Add content-detail reporting and presentation for authorized resources.
- Add rankings/trending filters, pagination, deterministic ordering and period metadata.
- Surface views, unique viewers, interactions and available-history limitations without conflating metrics.
- Reuse existing frontend content links and accessible table/detail patterns.

## Implemented in this phase

No content analytics detail page, ranking/trending UI, or related endpoint implementation has been completed yet.

## Required outputs and acceptance criteria

- Unauthorized content analytics are not disclosed through direct URLs or filter changes.
- Empty/zero-data resources remain understandable and do not fail charts/tables.
- Sorting/filtering values are allowlisted server-side and page bounds are capped.
- Trend labels explain their period, scope and incomplete history where applicable.

## Validation evidence to record

Record request/component tests for resource scope, query controls, zero data, pagination, sorting, direct navigation and responsive behavior.

## Next phase

After core dashboard reporting is complete, proceed to [Phase 10 — Wine insights and navigation context](phase-10-wine-insights-and-navigation-context.md).