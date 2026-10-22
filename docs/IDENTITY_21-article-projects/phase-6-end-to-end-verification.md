# Article Projects — Phase 6: End-to-End Verification

## Status

Planned. This phase begins only after API and frontend feature work is complete.

## Required API verification

1. Reviewer creates, reads, updates, and deletes an owned Article Project.
2. Another Reviewer cannot list, search, show, update, or delete that Article Project.
3. Editors and Admins can manage Article Projects within the existing manager scope.
4. Linked Article, Review, Producer, and Vintage authorization is enforced.
5. Invalid nested updates roll back all scalar and association changes.
6. Stale association-only updates return a conflict.
7. Article edits change actual count without changing target count.
8. Deleting an Article Project preserves linked records; deleting an Article unlinks the Article Project.
9. Public Article and Review responses do not expose Article Project information.
10. Paginated Article Project queries avoid N+1 behavior and avoid loading Article bodies unnecessarily.

## Required checks

Run the relevant Rails migrations and focused RSpec model/request suites. Run the repository's standard Rails quality checks when available. Record exact commands, passing checks, failing checks, and unresolved issues in the implementation report.

## Documentation to finalize

Update the feature documentation with local setup, migration order, example requests, authorization rules, word-count semantics, concurrency behavior, package-workflow boundary, and version-one limitations.

## Completion gate

Do not describe the feature as complete while required migrations, focused tests, frontend checks, or agreed browser/manual verification remain failing.