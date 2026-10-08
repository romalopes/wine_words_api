# Phase 4 — Workflow, authorization, concurrency and mobile verification

## Status: Partially verified (October 7, 2026)

## Goal
Verify and refine the entire workspace implementation, covering workflow edge cases, authorization boundaries, concurrency safety, and mobile responsiveness.

## Description
- **Workflow verification:**
  - Extend existing frontend tests and Rails request specs to cover the new tab interactions.
  - Verify tab switching preserves edits (form state saved/restored).
  - Verify saving refreshes lock versions (to prevent stale updates).
  - Verify article save updates dashboard word counts (actual_word_count, word_count_remaining).
  - Verify notebooks survive reload and multiple notebooks can reference one vintage.
  - Verify concurrent saves produce a recoverable conflict (using existing `lock_version` mechanism).
- **Authorization and permissions:**
  - Test Reviewer access to their own projects and denial of unauthorized cross‑project access.
  - Test article/review permissions separately (e.g., a user may edit an article they own but not a review they don’t own).
  - Ensure notebook operations respect the same project‑level permissions as vintages/producers/reviews.
- **Concurrency:**
  - Test notebook reorder concurrency (simultaneous reordering by two users).
  - Test removing a project vintage while preserving notebook content (notebooks should remain associated with the vintage until the vintage is deleted, or handle appropriately).
  - Test project deletion while preserving Article and Review records (they should not be cascaded).
- **Mobile verification:**
  - Run the repository's relevant checks and verify the complete workflow at desktop and mobile widths.
  - Ensure tab navigation is touch‑friendly and layouts adapt to smaller screens.
  - Verify that rich‑text notebooks and article editing are usable on mobile devices.
- **Reporting:**
  - Document the checks run, results, and any remaining limitations.

## Acceptance Criteria
- Tab switching preserves edits; saving refreshes lock versions; article save updates dashboard word counts; notebooks survive reload; multiple notebooks can reference one vintage; concurrent saves produce a recoverable conflict.
- Reviewer can access their own projects and is denied unauthorized cross‑project access.
- Article and review permissions are enforced independently.
- Notebook reorder concurrency is handled gracefully.
- Removing a project vintage preserves notebook content (or provides a clear conflict/resolution path).
- Project deletion does not destroy associated Article or Review records.
- Workspace functions correctly at mobile breakpoints (e.g., tabs collapse to a dropdown or remain tappable).
- All existing tests pass, and new tests cover the added functionality.

## Notes
- This phase is about verification and robustness, not major feature additions.
- It builds on all previous phases (1‑3) to ensure the workspace is production‑ready.
- Notebook updates and deletes now use optimistic locking. A stale write returns
  a `409` response and the detail page keeps the local draft visible while
  offering a reload of the current server version.

## Completed verification

- Rails request coverage verifies notebook CRUD, draft review creation,
  owner-scoped denial of another Reviewer's notebook access, and stale notebook
  update recovery.
- Frontend component coverage verifies detail navigation, project deletion,
  draft-review creation, and preservation of typed notebook input after a
  `409` conflict.
- Completed checks on October 7, 2026:
  - `bundle exec rspec spec/requests/api/v1/article_projects_spec.rb` —
    10 examples, 0 failures.
  - `npx vitest run src/components/ArticleProjectDetail.test.tsx` —
    5 tests passed.
  - `npm run build` — passed.
  - `git diff --check` — passed in the API and frontend repositories.

## Remaining verification and limitations

- Full URL-backed tab workflow, embedded article-editor behavior, and its
  associated word-count checks remain outside the current detail-page slice.
- Notebook reordering and its concurrent-reorder coverage are not implemented.
- Removing a project vintage currently follows the existing dependent-delete
  association behavior; preserving/detaching notebooks requires an explicit
  product decision and implementation.
- A complete manual desktop/mobile smoke test and broader authorization tests
  for independent Article and Review ownership remain to be run.
- The wider frontend typecheck still has unrelated pre-existing errors. A
  filtered check found no errors in the Article Project files changed for this
  increment.