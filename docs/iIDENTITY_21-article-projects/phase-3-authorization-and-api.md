# Article Projects — Phase 3: Authorization and Transactional API

## Status

Planned. Phases 1 and 2 are prerequisites.

## Objective

Add scoped Article Project CRUD under `/api/v1/article_projects` using the existing Rails API conventions and role predicates.

## Access model

| User type | Article Project access |
| --- | --- |
| Guest / Reader | None |
| Reviewer | CRUD for Article Projects where `created_by_id == current_user.id` |
| Editor / Admin | CRUD for all Article Projects within existing application boundaries |
| Legacy manager equivalent | Same broader scope currently represented by existing manager behavior |

`created_by_id` is assigned from `current_user` during create and is never permitted in request parameters.

## Implementation constraints

- Scope index, filters, totals, summaries, show, update, and destroy before record access.
- Reuse the existing `wine_manager?`/ownership approach; do not introduce an unrelated authorization system.
- Authorize each linked Article, Review, Producer, and Vintage separately using its existing visibility/management scope.
- Keep public Article and Review serializers free of private Article Project data.
- Require `lock_version` on every update, including association-only mutations; return a conflict response for stale updates.
- Perform scalar and nested join changes in a transaction.

## Nested mutation contract

- Target IDs create new joins.
- Join IDs update existing joins.
- Join ID plus `_destroy: true` removes the join.
- Omitted association keys leave the association untouched.
- Empty arrays do not clear associations.
- Existing join targets cannot be replaced by changing target IDs.
- Join IDs belonging to another Article Project are rejected.
- `article_id: null` unlinks the Article.

## API work

Add `index`, `show`, `create`, `update`, and `destroy` routes and an Article Project serializer with detail/list shapes appropriate to actual consumers. Support allowlisted `name`, `deadline`, `created_at`, and `updated_at` sorts; define deterministic secondary sorts and null-deadline behavior.

Article Project validation responses must preserve field attribution where possible. Normalize uniqueness violations into useful validation responses. Stale writes must use a distinct conflict status and payload.

## Tests required

Request specs must cover ownership scope, editor/admin scope, owner spoofing, linked-record authorization, cross-project join-ID attacks, rollback on invalid nested payloads, article uniqueness, filtering, pagination, list summaries, stale scalar writes, and stale association-only writes.

## Exit gate

A Reviewer can fully manage only their own Article Project; broader managers can manage their authorized scope; no unauthorized Article Project or linked record is disclosed.