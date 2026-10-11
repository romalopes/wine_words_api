# Content Analytics — Phase 5: Frontend Tracking

## Status

Planned as of October 11, 2026. Prerequisite: [Phase 4](phase-4-ingestion-http-api.md) provides the server contract.

## Objective

Track successful authorized Wine, Review and Article detail loads without blocking content rendering or overstating navigation data.

## Scope

- Add a browser visitor UUID subject to the approved consent policy, with in-memory fallback if persistent storage is unavailable.
- Trigger one non-blocking event after successful authorized detail loading.
- Suppress client duplicates caused by StrictMode, rerenders, remounts and navigation changes; backend remains the correctness boundary.
- Capture only allowlisted router navigation context for a real Wine-to-Review action.

## Implemented in this phase

No frontend analytics identity, tracker, detail-page integration, consent control or navigation-context implementation has been added yet.

## Required outputs and acceptance criteria

- Consent withholding/withdrawal prevents tracking and clears persistent IDs according to the approved contract.
- Tracking failure, unavailable storage and API failure never break content use and do not create an offline queue or automatic retry.
- Direct Review loads have no inferred Wine source.
- Navigation context is labelled as observed accepted transitions, not a click or conversion funnel.

## Validation evidence to record

Record component/service paths, unit tests, request suppression scenarios, consent/storage fallback tests and browser/manual smoke results.

## Next phase

After accepted event production is confirmed, proceed to [Phase 6 — Reporting periods and authorization scopes](phase-6-reporting-periods-and-scopes.md).