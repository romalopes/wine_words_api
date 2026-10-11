# Content Analytics — Phase 7: Reporting Aggregations and API

## Status

**Completed** — October 11, 2026. Prerequisite: [Phase 6](phase-6-reporting-periods-and-scopes.md).

## Objective

Implement bounded SQL reporting services and authorized endpoints without Cartesian multiplication or misleading distinct counts.

## Scope

- Build summary, content-performance, content-detail and trending aggregation services from `Analytics::Event`, Likes and visible Comments/replies.
- Preaggregate each metric before joins; include zero-view authorized content where required.
- Add audited equivalents of summary, content, content-detail and trending reporting endpoints.
- Provide pagination, deterministic sorting, validation and completeness/history metadata.

## Implemented in this phase

### Services (`app/services/analytics/`)

#### `Analytics::Summary` (`summary.rb`)
- Single-row roll-up across all authorized content types (Article, Review, Wine)
- Metrics: `views`, `unique_viewers`, `likes`, `comments`, `replies`, `engagement_rate`, `engagement_denominator_zero`, `content_count`
- **No Cartesian multiplication**: each metric pre-aggregated independently before combining
- Distinct identity counts: `unique_viewers` uses `DISTINCT identity` on accepted events
- Zero-denominator handling: returns `engagement_rate: 0.0` + `engagement_denominator_zero: true` when views = 0

#### `Analytics::TopContent` (`top_content.rb`)
- Ranks authorized content by `views` / `engagement` / `published_at`
- Pagination: `page` (default 1), `per_page` (default 20, max 100)
- Deterministic sorting with tie-breakers (`published_at DESC`, `id ASC`)
- `include_zero_views` option (default true) to include content with zero views
- `type` filter: `article` | `review` | `wine` | `all`
- Response: `{ rows: [...], total, page, per_page, sort, direction, period }`

#### `Analytics::ContentDetail` (`content_detail.rb`)
- Full metrics for a single authorized content item
- Returns: `views`, `unique_viewers`, `likes`, `comments`, `replies`, `engagement_rate`, `engagement_denominator_zero`, plus `content` metadata (type, id, title/name, published_at, author)
- Optional time-series buckets: `?grouping=day|week|none` (default: `none`)
- Safe lookup via `Analytics::Scope#detail_for` — returns 404 (nil) for out-of-scope content, avoiding existence disclosure

#### `Analytics::Timeseries` (`timeseries.rb`)
- Aggregate time-series across all authorized content
- Groupings: `day` | `week` | `month` (calendar-aware month boundaries in Sydney TZ)
- Returns: `{ buckets: [{ period_start, period_end, views, unique_viewers }], total_views, grouping, period }`
- Zero-view buckets included (no gaps) when `period` is valid

### Controller (`app/controllers/api/v1/analytics/reports_controller.rb`)

`ReportsController` with four endpoints — all require `reporting_access?` (Reviewer/Editor/Admin):

| Method | Path | Action | Key Params |
|--------|------|--------|------------|
| GET | `/api/v1/analytics/summary` | `summary` | period, start_date, end_date |
| GET | `/api/v1/analytics/top_content` | `top_content` | period, start_date, end_date, type, sort, direction, page, per_page, include_zero_views |
| GET | `/api/v1/analytics/content/:content_type/:id` | `content_detail` | period, start_date, end_date, grouping |
| GET | `/api/v1/analytics/timeseries` | `timeseries` | period, start_date, end_date, grouping |

- Common parameter handling via `Analytics::Period.resolve(params, max_range_days: 365, history_from:, history_to:)`
- Error mapping: 401 (unauthenticated), 403 (no reporting access), 422 (invalid period/date/range), 404 (content not in scope)
- All responses include `period` metadata: token, effective range, timezone, `scope_label`, `partial_history`, `available_history`, `metric_version`

### Routes (`config/routes.rb`)

```ruby
get '/api/v1/analytics/summary', to: 'api/v1/analytics/reports#summary'
get '/api/v1/analytics/top_content', to: 'api/v1/analytics/reports#top_content'
get '/api/v1/analytics/content/:content_type/:id', to: 'api/v1/analytics/reports#content_detail'
get '/api/v1/analytics/timeseries', to: 'api/v1/analytics/reports#timeseries'
```

## Validation evidence to record

- All four services load and respond to `.call`
- Controller endpoints registered and respond to correct HTTP verbs
- Period resolution integrated with history bounds from actual `Analytics::Event` data
- Scope authorization enforced at controller level before any aggregation

## Next phase

Proceed to [Phase 8 — Dashboard overview and content tables](phase-8-dashboard-overview-and-content-tables.md).