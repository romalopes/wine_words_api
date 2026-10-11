# Content Analytics — Phase 8: Dashboard Overview and Content Tables

## Status

**Completed with bug fix** — October 11, 2026. Prerequisite: [Phase 7](phase-7-reporting-aggregations-and-api.md).

## Objective

Deliver the first useful, responsive and accessible analytics dashboard surfaces using only authorized reporting API data.

## Scope

- Add dashboard navigation and role-aware entry points.
- Build overview KPI cards, period controls, definitions, partial-history/completeness labels and clear scope labels.
- Build paginated/sortable content performance tables with loading, empty, error and retry states.
- Preserve the product wording: Reviewer reporting is "Your editorial content + global Wines," not site-wide.

## Implemented in this phase

### Frontend Components (`wine_words/src/components/analytics/`)

- **`AnalyticsDashboard.tsx`** — Main dashboard with KPI cards, period selector, timeseries chart, and paginated content table
- **`ContentTable.tsx`** — Sortable, paginated content performance table with loading/empty/error/retry states
- **`TimeseriesChart.tsx`** — Responsive timeseries visualization (daily/weekly/monthly groupings)
- **`PeriodSelector.tsx`** — Period selection control with predefined ranges
- **`ContentAnalyticsDetail.tsx`** — Per-content detail view (stub for Phase 9)

### Navigation & Routing

- Dashboard route `/analytics` added in `AppRoutes.tsx`
- "Analytics" nav item in `Header.tsx` — gated by `canAccessAnalytics(effectiveIdentity)` for Admin/Editor/Reviewer

### Bug Fix (October 11, 2026)

**Issue:** Dashboard showed "Analytics Access Required" for Admin users despite valid backend authorization.

**Root Cause:** `AnalyticsDashboard.tsx:61` used incorrect role check:
```tsx
// BROKEN - used singular `role` (string) instead of `roles` (array), lowercase vs capitalized
const hasReportingAccess = user && ["admin", "editor", "reviewer"].includes(user.role);
```

**Fix:** Updated to use shared `canAccessAnalytics()` utility from `constants/roles.ts`:
```tsx
// FIXED - uses roles array with correct capitalization (Admin/Editor/Reviewer)
const hasReportingAccess = canAccessAnalytics(user);
```

This aligns with `Header.tsx` which already used `canAccessAnalytics(effectiveIdentity)` correctly.

### Backend Integration

- Consumes all four Phase 7 reporting endpoints: `summary`, `top_content`, `timeseries`, `content_detail`
- Period resolution with history bounds and scope metadata displayed in footer
- Proper error handling for 401/403/422 responses

## Required outputs and acceptance criteria

- Guest/Reader users receive no private dashboard UI and tolerate backend denial safely.
- Tables and controls work with keyboard navigation and narrow viewports.
- Metric definitions, reporting timezone and partial-history limits are visible rather than implied.
- No client-side role gating substitutes for backend authorization.
- **Role gating uses shared `canAccessAnalytics()` utility** — consistent between Header nav and Dashboard access check.

## Validation evidence to record

- Component paths: `wine_words/src/components/analytics/AnalyticsDashboard.tsx`, `ContentTable.tsx`, `TimeseriesChart.tsx`, `PeriodSelector.tsx`
- Responsive/accessibility checks: period selector, sortable table, chart groupings
- Frontend tests: (to be added)
- API error states: 401/403/422 handled with user-facing messages
- Manual role-based smoke: Admin/Editor/Reviewer see dashboard; Reader/Guest see "Analytics Access Required" banner

## Next phase

Proceed to [Phase 9 — Content details, rankings and trending](phase-9-content-details-rankings-and-trending.md).
