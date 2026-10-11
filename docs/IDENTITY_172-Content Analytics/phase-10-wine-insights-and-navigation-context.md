# Content Analytics — Phase 10: Wine Insights and Navigation Context

## Status

Planned as of October 11, 2026. Prerequisite: [Phase 9](phase-9-content-details-rankings-and-trending.md).

## Objective

Add Wine-specific analytical groupings and carefully bounded navigation context without presenting overlapping categories or deduplicated events as conversion data.

## Scope

- Aggregate Wine views through verified producer, region and grape associations.
- Deduplicate duplicate association rows and calculate group-level distinct identities correctly.
- Label multi-grape/multi-region categories as overlapping and non-additive.
- Validate source context for actual Wine-to-Review navigation and expose it only as observed accepted transitions.

## Implemented in this phase

No Wine insights service, category UI, navigation-context validation or observed-transition reporting has been implemented yet.

## Required outputs and acceptance criteria

- One Wine with multiple grapes/regions is credited to each applicable group without multiplying a group’s raw event count.
- Direct Review loads are not attributed to Wine navigation.
- Invalid or unrelated source resource metadata is not trusted.
- UI and documentation explicitly state that this is not a complete click or conversion funnel.

## Validation evidence to record

Record association-edge-case specs, group distinct-count tests, direct-load tests, source-validation tests and UI labels.

## Next phase

After product reporting semantics are complete, proceed to [Phase 11 — Diagnostics, retention and erasure](phase-11-diagnostics-retention-and-erasure.md).