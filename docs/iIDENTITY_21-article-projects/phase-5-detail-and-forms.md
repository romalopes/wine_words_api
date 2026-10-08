# Article Projects — Phase 5: Detail and Forms (API Prerequisites)

## Status

Planned. This API repository document records the backend contract needed by the Article Project detail and edit UI.

## Required API support

- `GET /api/v1/article_projects/:id` returns Article Project overview, owner summary, read-only word-count fields, overdue status, linked Article summary, join IDs, linked producer/vintage/review summaries, and vintage counts.
- `POST`, `PATCH`, and `DELETE` preserve atomicity, field-level validation information, lock-version behavior, and authorization from Phase 3.
- Existing searchable Article, Producer, Vintage, and Review endpoints must enforce their own visibility scope when used as picker sources.
- Article Project mutation responses must return refreshed join IDs and `lock_version` so the UI can maintain exact local form state.

## Article draft creation boundary

Article Project API work does not add a special bypass for Article creation. If the UI creates an Article draft, it must use the normal authorized Article workflow, then submit a normal authorized Article Project update to link it.

If Article creation succeeds but linking fails, the Article remains valid and the failed link is reported. Neither API may claim the Article Project link succeeded when it did not.

## Explicit non-goals

- No underlying Producer, Vintage, Review, or Article updates through Article Project nested parameters.
- No implicit Article Project-to-Article relation synchronization.
- No WinePackage creation, receipt synchronization, shipment tracking, or producer email.

## Exit gate

The frontend can edit all Article Project relationships using join IDs without deleting linked domain records or silently overwriting concurrent changes.