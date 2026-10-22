# Article Projects — Phase 4: Frontend Service and List (API Prerequisites)

## Status

Planned. This API repository document records the backend contract required by frontend Phase 4.

## API contract required by the frontend

- `GET /api/v1/article_projects` returns a paginated Article Project list using the repository's existing pagination envelope.
- The list accepts `q`, `project_status`, drafting-status filter, `overdue`, pagination parameters, and allowlisted sorting.
- The response includes only list-level data: identifiers, name, publication, status values, deadline, overdue flag, owner summary when authorized, and grouped vintage counts.
- The response must be scoped before filtering, aggregation, totals, and pagination.
- Article Project list serialization must not load Article body content solely for a list response.
- Unauthorized requests follow established API error conventions.

## Frontend integration handoff

The frontend will create `articleProjectsApi.list`, add `/article-projects`, and use the existing request client. It needs stable pagination metadata, filter behavior, and a retry-safe error payload before UI work begins.

## Verification

Before frontend implementation, add request specs demonstrating that Reviewer totals and results include only owned Article Projects while manager scopes include their authorized broader set.

## Exit gate

The list endpoint is stable, efficient, documented by tests, and ready for frontend consumption.