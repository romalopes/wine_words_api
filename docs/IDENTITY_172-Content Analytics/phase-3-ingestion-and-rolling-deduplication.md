# Content Analytics — Phase 3: Ingestion and Rolling Deduplication

## Status

Planned as of October 11, 2026. Prerequisite: [Phase 2](phase-2-schema-and-lifecycle.md) supplies the validated event model.

## Objective

Implement server-side view acceptance and one exact, transaction-safe 30-minute rolling deduplication strategy.

## Scope

- Build audited identity, visibility, exclusion and tracking services.
- Exclude Admins and verified Article/Review authors viewing their own content; do not invent Wine-owner exclusions.
- Use server time and a bounded, configurable 1,800-second window.
- Prefer a PostgreSQL transaction-level advisory lock with stable signed lock keys, post-lock read, and full-tuple duplicate verification.

## Implemented in this phase

No tracking service, advisory lock, Redis alternative or concurrency test has been implemented yet.

## Required outputs and acceptance criteria

- Two simultaneous requests for the same resource/identity create one event.
- Requests two seconds apart across fixed half-hour boundaries still deduplicate.
- A request exactly 30 minutes after the last accepted view is accepted; ignored attempts do not move the window.
- Inaccessible, draft, preview, Admin and self-authored loads produce no event.
- Lock/statement timeout and database failure drop analytics without affecting content delivery.

## Validation evidence to record

Record the selected strategy, transaction/timeout configuration, real separate-connection integration tests, boundary tests and provider/pool compatibility findings.

## Next phase

After concurrency correctness is demonstrated, proceed to [Phase 4 — Ingestion HTTP API](phase-4-ingestion-http-api.md).