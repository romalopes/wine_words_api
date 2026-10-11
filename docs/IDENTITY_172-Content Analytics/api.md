# Analytics API Reference

Version: 1.0 (Phase 11-13)
Last Updated: October 11, 2026

---

## Overview

The Content Analytics system provides privacy-first, opt-out respecting view tracking for Articles, Reviews, and Wines. This document covers the public ingestion endpoints, authenticated reporting endpoints, and admin-only diagnostics endpoints.

**Base URL**: `/api/v1/analytics`

**Authentication**:
- Ingestion endpoints: Public (no auth required, anonymous allowed)
- Reporting endpoints: Authenticated user with Reviewer/Editor/Admin role
- Diagnostics endpoints: Admin only + explicit feature flag

---

## Common Conventions

| Convention | Detail |
|------------|--------|
| Content Types | `Article`, `Review`, `Wine` (validated against `Analytics::Event::CONTENT_TYPES`) |
| Identity Format | `account:{id}` for logged-in users, `visitor:{uuid}` for anonymous |
| Timestamps | ISO 8601 UTC (e.g., `2026-10-11T15:30:00Z`) |
| Pagination | Page-based with `page` and `per_page` (max 50) |
| Errors | Standard Rails API error format with `error` and `message` keys |

---

## Ingestion Endpoints (Public)

### POST /api/v1/analytics/views

Record a content view event. Alias for `/events`.

**Headers**:
- `Content-Type: application/json`
- Optional: `X-Visitor-ID` (client-generated UUID for anonymous tracking)

**Request Body**:
```json
{
  "content_type": "Article",
  "content_id": 42,
  "viewed_at": "2026-10-11T15:30:00Z",
  "source": "direct",
  "referrer": "https://example.com/referrer",
  "viewport": "1920x1080"
}
```

| Field | Required | Type | Constraints |
|-------|----------|------|-------------|
| content_type | Yes | string | `Article`, `Review`, `Wine` |
| content_id | Yes | integer | > 0 |
| viewed_at | Yes | string | ISO 8601 UTC |
| source | No | string | Max 32 chars (e.g., `direct`, `navigation`, `search`) |
| referrer | No | string | Max 500 chars |
| viewport | No | string | Max 32 chars (e.g., `1920x1080`) |

---

## Reporting Endpoints (Authenticated - Reviewer/Editor/Admin)

### GET /api/v1/analytics/summary

Aggregate overview across all content.

**Query Parameters**:
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| start_date | string | 30 days ago | ISO 8601 start boundary |
| end_date | string | now | ISO 8601 end boundary |

**Response** (200 OK):
```json
{
  "total_views": 15420,
  "unique_visitors": 3421,
  "views_by_type": {
    "Article": 8920,
    "Review": 4100,
    "Wine": 2400
  },
  "top_sources": [
    { "source": "direct", "count": 8200 },
    { "source": "search", "count": 4100 },
    { "source": "navigation", "count": 3120 }
  ]
}
```

### GET /api/v1/analytics/top_content

Ranked content by view count.

**Query Parameters**:
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| content_type | string | all | Filter by `Article`, `Review`, or `Wine` |
| limit | integer | 10 | Max 50 |
| start_date | string | 30 days ago | ISO 8601 |
| end_date | string | now | ISO 8601 |

**Response** (200 OK):
```json
{
  "content": [
    { "content_type": "Article", "content_id": 42, "title": "Best Wines 2026", "view_count": 1250 },
    { "content_type": "Wine", "content_id": 17, "title": "Château Margaux 2015", "view_count": 890 }
  ],
  "period": { "start": "2026-09-11T00:00:00Z", "end": "2026-10-11T00:00:00Z" }
}
```

### GET /api/v1/analytics/content/:content_type/:id

Detailed analytics for a single content item.

**Path Parameters**:
- `content_type`: `Article`, `Review`, or `Wine`
- `id`: Content ID

**Query Parameters**:
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| start_date | string | 30 days ago | ISO 8601 |
| end_date | string | now | ISO 8601 |

**Response** (200 OK):
```json
{
  "content": { "type": "Article", "id": 42, "title": "Best Wines 2026" },
  "views": 1250,
  "unique_visitors": 890,
  "by_source": { "direct": 600, "search": 450, "navigation": 200 },
  "timeseries": [
    { "date": "2026-10-01", "views": 45 },
    { "date": "2026-10-02", "views": 52 }
  ]
}
```

### GET /api/v1/analytics/timeseries

Time-series data for charts.

**Query Parameters**:
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| content_type | string | all | Filter by type |
| content_id | integer | all | Filter by specific content |
| granularity | string | day | `hour`, `day`, `week`, `month` |
| start_date | string | 30 days ago | ISO 8601 |
| end_date | string | now | ISO 8601 |

**Response** (200 OK):
```json
{
  "granularity": "day",
  "series": [
    { "period": "2026-10-01", "views": 450, "unique_visitors": 320 },
    { "period": "2026-10-02", "views": 520, "unique_visitors": 380 }
  ]
}
```

### GET /api/v1/analytics/wine-insights

Wine-specific analytics (Phase 10).

**Query Parameters**:
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| wine_id | integer | required | Wine ID |
| start_date | string | 90 days ago | ISO 8601 |
| end_date | string | now | ISO 8601 |

**Response** (200 OK):
```json
{
  "wine": { "id": 17, "name": "Château Margaux 2015" },
  "profile_views": 2400,
  "taste_parameter_breakdown": {
    "body": { "light": 10, "medium": 45, "full": 45 },
    "acidity": { "low": 15, "medium": 50, "high": 35 }
  },
  "comparison_percentiles": {
    "body": 78,
    "acidity": 42
  }
}
```
**Response** (201 Created):
```json
{
  "accepted": true,
  "event_id": 12345,
  "identity": "visitor:a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "deduplicated": false
}
```

**Response** (202 Accepted - Deduplicated):
```json
{
  "accepted": false,
  "rejection_reason": "dedup_window",
  "message": "Duplicate view within deduplication window"
}
```

**Rejection Reasons**:
- `dedup_window` - Duplicate view within 24h window per content+identity
- `opt_out` - User has analytics_opt_out enabled
- `invalid_payload` - Validation failed
- `excluded_role` - User role excluded from tracking
- `rate_limited` - Exceeded per-IP rate limit

### POST /api/v1/analytics/events

---

## Diagnostics Endpoints (Admin Only + Feature Flag)

> **Security**: These endpoints are **disabled by default**. Requires:
> 1. Admin role (`Role.name = 'Admin'`)
> 2. `AppSetting.boolean("analytics_diagnostics_enabled")` = true

### GET /api/v1/analytics/diagnostics/accepted

Paginated, masked inspection of accepted events.

**Query Parameters**:
| Param | Type | Default | Constraints |
|-------|------|---------|-------------|
| page | integer | 1 | ≥ 1 |
| per_page | integer | 25 | 1-50 |
| content_type | string | all | `Article`, `Review`, `Wine` |
| viewable_id | integer | all | > 0 |
| start_date | string | - | ISO 8601 (requires end_date) |
| end_date | string | - | ISO 8601 (requires start_date) |

**Response** (200 OK):
```json
{
  "events": [
    {
      "id": 12345,
      "viewable_type": "Article",
      "viewable_id": 42,
      "identity": "account:***",
      "viewed_at": "2026-10-11T15:30:00Z",
      "source": "direct",
      "referrer": "https://example.com",
      "viewport": "1920x1080",
      "visitor_key": "a1b2c3d4...",
      "created_at": "2026-10-11T15:30:01Z"
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 25,
    "total_count": 15420,
    "total_pages": 617
  },
  "scope_label": "Accepted events (masked)"
}
```

**Masking Rules**:
| Field | Masking |
|-------|---------|
| identity | `account:***` or `visitor:***` |
| referrer | Origin only (scheme://host[:port]) |
| visitor_key | First 8 chars + `...` |
| viewport, source | Unchanged (safe) |

### GET /api/v1/analytics/diagnostics/exclusion_reasons

Aggregate exclusion reason counts for rejected events.

**Query Parameters**:
| Param | Type | Default | Constraints |
|-------|------|---------|-------------|
| start_date | string | - | ISO 8601 (requires end_date) |
| end_date | string | - | ISO 8601 (requires start_date) |

**Response** (200 OK):
```json
{
  "exclusion_reasons": {
    "total_rejected": 342,
    "note": "Detailed rejection reasons not yet persisted; all rejections are aggregated. See ADR-010 for future enhancement."
  },
  "scope_label": "Exclusion reasons (aggregated)"
}
```

**Error** (403 Forbidden - Feature Disabled):
```json
{
  "error": "Diagnostics disabled",
  "message": "Enable via AppSetting 'analytics_diagnostics_enabled' (Admin only)"
}
```

---

## Consent & Opt-Out

### User Opt-Out
- Endpoint: `PATCH /api/v1/account/analytics_opt_out`
- Body: `{ "analytics_opt_out": true }`
- Effect: All subsequent events for that user are rejected with `opt_out`

### Visitor Erasure (GDPR)
- Admin only: `Analytics::Event.anonymize_visitor!(visitor_id)`
- Anonymizes identity to `visitor:erased-{uuid}` and clears `visitor_key`

### Account Erasure (GDPR)
- Admin only: `Analytics::Event.anonymize_account!(account_id)`
- Anonymizes identity to `visitor:erased-{account_id}` and clears `visitor_key`

### Full Erasure (Known Identity)
- Admin only: `Analytics::Event.erasure!(identity)`
- Requires exact identity string (`account:42` or `visitor:uuid`)

### Content Purge (Business Requirement)
- Admin only: `Analytics::Event.purge_content!(type, id)`
- Hard deletes all events for that content

### Content Archive
- Admin only: `Analytics::Event.archive_content!(type, id)`
- Soft archives by setting `accepted = false` (preserves for rollups)

---

## Rate Limiting

- Backed by Redis via `Rack::Attack`
- Per-IP limit on `/analytics/views` (configurable)
- Exceeding returns 429 with `rejection_reason: "rate_limited"`

---

## Feature Flags (AppSetting)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `analytics_diagnostics_enabled` | boolean | false | Gate for admin diagnostics endpoints |
| `logs_enabled` | boolean | true | Master audit log switch (affects all logging) |
| `use_test_email` | boolean | false | Email testing mode |
| `test_email` | string | ENV | Test email address |

**Managing via Rails Console**:
```ruby
# Enable diagnostics
AppSetting.set!("analytics_diagnostics_enabled", true)

# Disable diagnostics
AppSetting.set!("analytics_diagnostics_enabled", false)

# Check current value
AppSetting.boolean("analytics_diagnostics_enabled")
```

---

## Error Responses

| Status | Code | Meaning |
|--------|------|---------|
| 400 | invalid_payload | Validation failed |
| 401 | unauthorized | Missing/invalid auth token |
| 403 | forbidden | Insufficient role or feature disabled |
| 404 | not_found | Content not found |
| 422 | unprocessable_entity | Semantic validation failed |
| 429 | rate_limited | Rate limit exceeded |
| 500 | internal_server_error | Unexpected error |

---

## Versioning & Compatibility

- API versioned via URL path `/api/v1/`
- Breaking changes require new version path
- Field additions are non-breaking; clients must ignore unknown fields
- Deprecation notices in response headers 90 days before removal

---

## Related Documentation

- [Operations Guide](operations.md) - Deployment, rollback, maintenance
- [Phase 11 Implementation](phase-11-diagnostics-retention-and-erasure.md) - Diagnostics, retention, erasure
- [Phase 12 Security Review](phase-12-security-performance-and-e2e.md) - Security verification
Identical to `/views`. Maintained for semantic compatibility.