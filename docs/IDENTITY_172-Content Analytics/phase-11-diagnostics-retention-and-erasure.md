# Content Analytics — Phase 11: Diagnostics, Retention and Erasure

## Status

Planned as of October 11, 2026. Prerequisites: [Phase 2](phase-2-schema-and-lifecycle.md) and [Phase 10](phase-10-wine-insights-and-navigation-context.md).

## Objective

Provide bounded operational visibility and enforce the approved raw-event retention and deletion contracts without creating a shadow analytics dataset.

## Scope

- Add explicit-permission, Admin-only diagnostics for accepted events and aggregate exclusion reasons.
- Mask identities and prohibit raw IPs, tokens, names, full user agents and rejected-event storage.
- Implement idempotent, bounded, configurable retention cleanup with dry-run support and scheduler guidance.
- Implement protected account/known-visitor erasure, including dedup/cache cleanup when applicable.

## Implemented in this phase

No diagnostics endpoint, cleanup command/job, scheduler integration or analytics erasure workflow has been implemented yet.

## Required outputs and acceptance criteria

- Production event inspection is disabled by default and requires Admin plus explicit debug permission.
- Cleanup safely removes data before the retention cutoff in small repeatable batches and makes missing scheduling observable.
- Erasure removes events and identity artifacts without retaining account IDs in `visitor_key` values.
- Diagnostics remain paginated/capped and logs do not become indefinite raw-event storage.

## Validation evidence to record

Record permission tests, masked-output examples, dry-run and repeated-cleanup tests, retention boundary tests, erasure tests and scheduler operational instructions.

## Next phase

After operational controls are verified, proceed to [Phase 12 — Security, performance and end-to-end verification](phase-12-security-performance-and-e2e.md).