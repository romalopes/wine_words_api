# Content Analytics — Phase 8: Dashboard Overview and Content Tables

## Status

Planned as of October 11, 2026. Prerequisite: [Phase 7](phase-7-reporting-aggregations-and-api.md).

## Objective

Deliver the first useful, responsive and accessible analytics dashboard surfaces using only authorized reporting API data.

## Scope

- Add dashboard navigation and role-aware entry points.
- Build overview KPI cards, period controls, definitions, partial-history/completeness labels and clear scope labels.
- Build paginated/sortable content performance tables with loading, empty, error and retry states.
- Preserve the product wording: Reviewer reporting is “Your editorial content + global Wines,” not site-wide.

## Implemented in this phase

No analytics dashboard route, navigation item, overview component, content table or frontend test has been implemented yet.

## Required outputs and acceptance criteria

- Guest/Reader users receive no private dashboard UI and tolerate backend denial safely.
- Tables and controls work with keyboard navigation and narrow viewports.
- Metric definitions, reporting timezone and partial-history limits are visible rather than implied.
- No client-side role gating substitutes for backend authorization.

## Validation evidence to record

Record component paths, responsive/accessibility checks, frontend tests, API error states, and manual role-based smoke evidence.

## Next phase

After overview and tables are usable, proceed to [Phase 9 — Content details, rankings and trending](phase-9-content-details-rankings-and-trending.md).