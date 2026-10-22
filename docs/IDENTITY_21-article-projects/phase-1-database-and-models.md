# Article Projects — Phase 1: Database and Models

## Status

Planned. No migrations, models, or tests have been added yet.

## Objective

Add the Article Project persistence model and three tracking joins without altering the lifecycle of Articles, Reviews, Producers, Vintages, or WinePackages.

## Backend deliverables

1. Create `article projects` with `created_by_id` referencing `users`, optional `article_id`, optimistic-lock `lock_version`, timestamps, and the approved scalar fields.
2. Create `project_producers`, `project_vintages`, and `project_reviews` with foreign keys, timestamps, required defaults, and composite unique database indexes.
3. Add a unique index on nullable `article projects.article_id` so an Article can belong to at most one Article Project.
4. Add `Article Project`, `ProjectProducer`, `ProjectVintage`, and `ProjectReview` models with associations, validations, enums/constants, and nested attributes.
5. Add the reciprocal optional `Article#project` association with deletion behavior that clears `article projects.article_id` when an Article is deleted.
6. Add `User#created_projects` using `dependent: :nullify`, matching the application's non-cascading ownership-history convention.

## Required model rules

- `Article Project#name` is required, trimmed, and limited to 255 characters.
- `project_status` defaults to `initiated` and accepts only the stable keys approved in the feature specification.
- `drafting_status` defaults to `not_initiated` and accepts `not_initiated`, `initiated`, `in_progress`, and `finished`.
- `target_word_count`, when supplied, is a positive integer.
- `editor_email`, when supplied, must be a valid email address.
- A confirmed producer request implies `contacted: true`; contradictory submitted values must produce validation errors.
- Receipt date requires `received`; future receipt dates are invalid; clearing receipt resets date and bottle condition; non-default bottle condition requires `received`.
- Existing join targets are immutable. Changing a producer/vintage/review target requires removing the join and adding another.

## Deletion boundaries

| Action | Required result |
| --- | --- |
| Delete Article Project | Delete joins only; preserve linked domain records |
| Delete Article | Nullify its Article Project article link; preserve Article Project |
| Unlink Article | Preserve Article |
| Remove Article Project producer link | Preserve Producer and Article Project vintages |
| Remove Article Project vintage/review link | Preserve Vintage/Review |

No Article callback may update target word count. No Article Project callback may alter Article relationships. No package, shipment, notification, or email work belongs in this phase.

## Tests required

Add focused RSpec model tests for defaults, allowed statuses, scalar validation, join uniqueness, one-project-per-article enforcement, producer consistency, vintage workflow behavior, nested removal, and deletion behavior.

## Exit gate

Migrations apply cleanly and relevant model tests pass with database constraints independently enforcing the critical uniqueness rules.