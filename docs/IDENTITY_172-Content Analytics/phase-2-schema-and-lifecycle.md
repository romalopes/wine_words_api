# Content Analytics — Phase 2: Schema and Lifecycle Foundations

## Status

Planned as of October 11, 2026. Prerequisites: [Phase 0](phase-0-repository-audit.md) and [Phase 1](phase-1-metrics-identity-permissions-privacy.md).

## Objective

Add the audited `ContentView` persistence foundation and lifecycle behavior without promising historical rollups or orphan retention.

## Scope

- Create the polymorphic event model for Wine, Review and Article with server-derived identity fields and server timestamps.
- Add only measured/justified constraints and indexes, including type allowlisting and positive/valid identifier checks.
- Implement audited Account erasure and soft/hard content deletion behavior.
- Provide safe migration rollback for development; production rollback remains additive and operationally controlled.

## Implemented in this phase

No `ContentView` migration, model, index, lifecycle callback or test has been implemented yet.

## Required outputs and acceptance criteria

- Persist audited equivalents of `viewable_type`, `viewable_id`, optional account reference, UUID visitor ID, server `visitor_key`, `viewed_at`, and allowlisted source/navigation context.
- Unknown types cannot persist; client event time is not accepted in V1.
- Account deletion removes events and namespaced identity/dedup artifacts as required by the contract.
- Hard deletion removes raw references; soft archive behavior follows the verified lifecycle without accidental `dependent: :destroy`.
- Migration up/down and lifecycle tests pass without breaking editorial behavior.

## Validation evidence to record

Record migration names, schema/index decisions, rollback result, lifecycle specs, query-plan evidence for indexes, and deviations approved through ADRs.

## Next phase

After schema and lifecycle acceptance, proceed to [Phase 3 — Ingestion and rolling deduplication](phase-3-ingestion-and-rolling-deduplication.md).