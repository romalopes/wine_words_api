# Content Analytics — Phase 0: Repository Audit and Implementation Map

## Status

Planned as of October 11, 2026. No analytics feature code has been implemented in this phase.

## Objective

Replace the master plan's proposed paths and assumptions with verified facts from the Rails API and React frontend before any analytics code is changed.

## Scope

- Inspect current Wine, Review, Article, User, Account, Like and Comment models and associations.
- Map authentication, roles, authorship/coauthorship, readability, publication, deletion, routes, serializers, UI conventions, tests, PostgreSQL, cache, pooling and deployment.
- Record exact commit identifiers, file paths, absent capabilities and conflicts with the master plan.
- Select one justified atomic deduplication design; PostgreSQL transaction advisory locks remain the default unless an already-shared Redis deployment is verified.

## Implemented in this phase

No audit deliverable or feature implementation has been recorded yet. The initial planning inspection verified Rails 8.1.3, PostgreSQL, RSpec, React 19, TypeScript, Vite, React Router and Vitest, but it is not a substitute for the complete Phase 0 audit.

## Required outputs and acceptance criteria

- Create the verified repository audit, implementation map and required ADRs under `docs/analytics/`.
- Cite a real code reference for every ownership, visibility, role and deletion assertion.
- Explicitly distinguish `User` and `Account` semantics and do not infer Wine ownership.
- Identify reusable service, serializer, controller, route, test and frontend patterns.
- Record the branch/commit inspected in both repositories and unresolved decisions.

## Validation evidence to record

List inspected paths, Git commits, commands run, test-tool availability, database/provider findings, and the chosen deduplication rationale. No implementation acceptance may be claimed from documentation review alone.

## Next phase

After the audit exit gate is met, proceed to [Phase 1 — Metrics, identity, permissions and privacy](phase-1-metrics-identity-permissions-privacy.md). That phase must use verified Phase 0 facts rather than the proposed names in the master plan.