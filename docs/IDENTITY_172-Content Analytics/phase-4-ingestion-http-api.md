# Content Analytics — Phase 4: Ingestion HTTP API

## Status

Planned as of October 11, 2026. Prerequisite: [Phase 3](phase-3-ingestion-and-rolling-deduplication.md) provides the sole ingestion service.

## Objective

Expose the validated ingestion flow through a small, safe API endpoint that does not reveal private exclusion decisions.

## Scope

- Add the audited route/controller for `POST /api/v1/analytics/views`.
- Validate allowlisted content types, IDs, UUIDs and limited source/navigation metadata.
- Authenticate supplied credentials; expired or malformed credentials must use existing authentication errors rather than anonymous fallback.
- Return one neutral valid-event response such as `{"accepted":true}` for counted and intentionally ignored requests.

## Implemented in this phase

No analytics ingestion route, controller, request contract, rate limit or request spec has been implemented yet.

## Required outputs and acceptance criteria

- Missing credentials may track anonymously when allowed; supplied invalid credentials cannot bypass exclusions.
- Invalid payload, unavailable content, rate-limit and outage behavior follow existing API conventions.
- No response reveals whether a person is an Admin, owner or author.
- Source metadata is untrusted, bounded and relationship-validated; invalid optional metadata is discarded without breaking a valid event.

## Validation evidence to record

Record route/controller paths, payload and authentication request specs, rate-limit integration, neutral-response assertions and CORS behavior.

## Next phase

After the endpoint contract is stable, proceed to [Phase 5 — Frontend tracking](phase-5-frontend-tracking.md).