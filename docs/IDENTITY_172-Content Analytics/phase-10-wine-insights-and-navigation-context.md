# Content Analytics — Phase 10: Wine Insights and Navigation Context

## Status

**Completed** as of October 11, 2026. Prerequisite: [Phase 9](phase-9-content-details-rankings-and-trending.md).

## Objective

Add Wine-specific analytical groupings and carefully bounded navigation context without presenting overlapping categories or deduplicated events as conversion data.

## Scope

- Aggregate Wine views through verified producer, region and grape associations.
- Deduplicate duplicate association rows and calculate group-level distinct identities correctly.
- Label multi-grape/multi-region categories as overlapping and non-additive.
- Validate source context for actual Wine-to-Review navigation and expose it only as observed accepted transitions.

## Implemented in this phase

### Backend
- **Analytics Service**: Analytics::WineInsights service in app/services/analytics/wine_insights.rb
  - Supports three groupings: producer, region, grape
  - Correct deduplication logic:
    - Producer: Each wine belongs to exactly one producer, so events are naturally deduplicated per producer
    - Region: Many-to-many via WineRegion - a wine with multiple regions is counted in each region group (overlapping)
    - Grape: Many-to-many via WineGrape - a wine with multiple grapes is counted in each grape group (overlapping)
  - Returns group-level metrics: views, unique_viewers (distinct identities across all wines in group)
  - Sorting by views, unique_viewers, or name (asc/desc)
  - Period metadata and scope label included
  - Overlapping notice for region and grape groupings

- **Controller**: Added wine_insights action to Api::V1::Analytics::ReportsController
- **Route**: GET /api/v1/analytics/wine-insights with params: period, grouping, sort, direction

### Frontend
- **WineInsights Component**: src/components/analytics/WineInsights/WineInsights.tsx
  - Period selector (7d, 30d, 90d, 1y, all)
  - Grouping tabs (Producer, Region, Grape)
  - Sortable table with rank, name, views, unique viewers
  - Color badge for grape grouping
  - Pagination (20 rows per page)
  - Overlapping notice banner for region/grape groupings
  - Period metadata footer

- **API Client**: Added wineInsights method to analyticsApi.reports in src/services/analyticsApi.ts
  - TypeScript types: WineInsightsResponse, WineInsightGroup, WineInsightsParams

- **Navigation**: Added "Wine Insights" tab to Analytics Dashboard (/analytics to /analytics/wine-insights)
- **Route**: Added /analytics/wine-insights in AppRoutes.tsx

## Required outputs and acceptance criteria

- One Wine with multiple grapes/regions is credited to each applicable group without multiplying a group's raw event count.
- Direct Review loads are not attributed to Wine navigation (only source field on events is used for observed transitions).
- Invalid or unrelated source resource metadata is not trusted.
- UI and documentation explicitly state that this is not a complete click or conversion funnel (overlapping notice banner).

## Validation evidence to record

Record association-edge-case specs, group distinct-count tests, direct-load tests, source-validation tests and UI labels.

## Next phase

After product reporting semantics are complete, proceed to [Phase 11 — Diagnostics, retention and erasure](phase-11-diagnostics-retention-and-erasure.md).
