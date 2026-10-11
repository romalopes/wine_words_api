# Content Analytics — Phase 9: Content Details, Rankings and Trending

## Status

**Completed** — October 11, 2026. Prerequisite: [Phase 8](phase-8-dashboard-overview-and-content-tables.md).

## Objective

Extend the dashboard with authorized per-content detail, ranking and trending views while retaining safe scope and metric semantics.

## Scope

- Add content-detail reporting and presentation for authorized resources.
- Add rankings/trending filters, pagination, deterministic ordering and period metadata.
- Surface views, unique viewers, interactions and available-history limitations without conflating metrics.
- Reuse existing frontend content links and accessible table/detail patterns.

## Implemented in this phase

### Backend (already delivered in Phase 7)

- **`GET /api/v1/analytics/content/:content_type/:id`** — Content detail endpoint returning views, unique_viewers, likes, comments, replies, engagement_rate, engagement_denominator_zero, content metadata (type, id, title, published_at, author_name), and optional time-series buckets via `?grouping=day|week|none`
- Service: `Analytics::ContentDetail` (`wine_words_api/app/services/analytics/content_detail.rb`)
- Authorization: reuses Phase 6/7 scope logic — Admin/Editor see all; Reviewer sees own Articles/Reviews + global Wines

### Frontend Components (`wine_words/src/components/analytics/`)

- **`ContentAnalyticsDetail.tsx`** — Full per-content detail page with:
  - KPI cards: Views, Unique Viewers, Likes, Comments, Replies, Engagement Rate (shows "—" when denominator is zero)
  - Content metadata header: title, type badge, published date, author
  - Responsive timeseries chart with period selector (7d/30d/90d/1y/all) and grouping selector (Daily/Weekly/Monthly)
  - Period/scope/footer metadata: period label, timezone, partial-history indicator
  - Loading, error (with retry/back button), and empty states
  - Accessible markup (ARIA labels, semantic sections, keyboard-navigable)
- **Route**: `/analytics/content/:contentType/:contentId` added in `AppRoutes.tsx`
- **Navigation from dashboard**: `ContentTable` rows are clickable (keyboard + mouse) → `handleRowClick` in `AnalyticsDashboard.tsx` navigates to detail view with correct type mapping (Article→article, Review→review, Wine→wine)
- **Reuses shared components**: `TimeseriesChart`, `PeriodSelector`, format utilities

### Ranking/Trending

- Dashboard content table (`ContentTable` in `AnalyticsDashboard`) provides sortable, paginated ranking by Views, Engagement Rate, or Published Date (asc/desc)
- Deterministic ordering: secondary sort by `content_id` for stability
- Period metadata displayed in dashboard footer and detail page footer

## Required outputs and acceptance criteria

- Unauthorized content analytics are not disclosed through direct URLs or filter changes.
- Empty/zero-data resources remain understandable and do not fail charts/tables.
- Sorting/filtering values are allowlisted server-side and page bounds are capped.
- Trend labels explain their period, scope and incomplete history where applicable.

## Validation evidence to record

- **Backend**: `Analytics::ContentDetail` service specs — scope authorization (Admin/Editor/Reviewer), zero-views engagement handling, timeseries bucket grouping (day/week/none), period metadata
- **Frontend**: `ContentAnalyticsDetail` component tests — loading/error/empty states, KPI rendering, period/grouping controls, timeseries chart integration, keyboard navigation, direct URL access with unauthorized role (403/redirect)
- **Integration**: Dashboard → Detail navigation (click + Enter key), type mapping correctness, period/grouping persistence on navigation back
- **Accessibility**: ARIA labels, semantic landmarks, focus management, color contrast on badges/KPIs

## Next phase

Proceed to [Phase 10 — Wine insights and navigation context](phase-10-wine-insights-and-navigation-context.md).