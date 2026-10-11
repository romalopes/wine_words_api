# Content Analytics — Phase 1: Metrics, Identity, Permissions and Privacy

## Status

Planned as of October 11, 2026. Prerequisite: [Phase 0](phase-0-repository-audit.md) must verify the current authorization and lifecycle model.

## Objective

Turn the master plan's product rules into testable, repository-specific contracts before persistence or endpoint implementation.

## Scope

- Define accepted views, resource unique viewers, authorized-set unique visitors, surviving period Likes, visible top-level Comments/replies and interaction-rate behavior.
- Lock `[start_at, end_at)` UTC intervals derived from Australia/Sydney reporting dates.
- Define identity as `account:<id>` when authenticated and `visitor:<uuid>` otherwise, without V1 anonymous-to-account merging.
- Map Reviewer, Editor, Admin, Reader and Guest analytics access to verified application permissions.
- Define consent/opt-out, 90-day proposed raw retention, partial-history labels, account/visitor erasure and mutable interaction-history limitations.

## Implemented in this phase

No analytics contracts, fixtures or ADRs have been implemented yet. The master plan is the pending source specification, not evidence of application behavior.

## Required outputs and acceptance criteria

- Create the metric dictionary, identity/privacy contract, permissions contract and identity/dedup/retention ADRs under `docs/analytics/`.
- Ensure rates can exceed 100%, return `0.0` with a denominator-zero indicator, and never mix period and lifetime values.
- State Reviewer scope as own editorial content plus global Wines; do not call it site-wide.
- Document that consent/legal sufficiency and anonymization require separate verified decisions.

## Validation evidence to record

Record representative fixtures, role/scope examples, date-boundary examples, stakeholder decisions and links to the verified Phase 0 findings.

## Next phase

After contracts are approved, proceed to [Phase 2 — Schema and lifecycle foundations](phase-2-schema-and-lifecycle.md).