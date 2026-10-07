# Phase 3 — Reviews integration

## Status: Implemented (October 7, 2026)

## Goal
Integrate review creation and editing within the Wines & Notes tab, allowing users to create draft reviews from notebook content and link existing reviews to the project.

## Description
- From any notebook in the Wines & Notes tab, provide an action “Create draft review from this notebook”:
  - Opens a form (reusing `ReviewForm` or similar) pre‑populated with the notebook’s title and content.
  - The review defaults to “draft” status.
  - User can edit the review independently and then save it.
- The API links the newly created draft to the project atomically; the user can then edit it independently.
- Allow linking existing reviews to the project (reusing existing lookup functionality) and editing linked reviews within the Wines & Notes tab.
- Ensure notebook content and review content remain independently editable (acceptance criterion).
- Backend changes:
  - Add a custom action to create a review from a notebook:
    - `POST /article_projects/:id/article_project_vintages/:article_project_vintage_id/notebooks/:notebook_id/review`
    - This endpoint creates a new `Review` (draft) using the notebook’s title/content, associates it with the project via `ArticleProjectReview`, and returns the review.
    - Validate that the review inherits the vintage/wine context from the notebook’s parent vintage.
  - Ensure the existing `ArticleProjectReview` association remains unchanged.
  - Update serializers if needed to include review details in the vintage or notebook payloads.
- Frontend changes:
  - Extend the notebook UI in the Wines & Notes tab with a “Create review from this notebook” button/action.
  - Handle the review creation flow (form display, saving, linking).
  - Allow editing of linked reviews inline (similar to how notebooks are edited).
  - Keep the existing “Link existing review” functionality (from the vintage or project level) functional.
  - Ensure that unlinking a notebook or review does not delete the underlying record (only removes the association).

## Acceptance Criteria
- Reviews created from notes default to draft.
- Required fields are validated before saving.
- Notebook and review content remain independently editable.
- Existing unassociated project review links remain visible.
- Unlinking or deleting notes preserves Review records.
- If review creation succeeds but association fails, retain the saved review ID and offer a retry without duplicate creation.
- Keeping a project review linked to the article remains an explicit separate action (as today).

## Notes
- This phase builds on the notebooks added in Phase 2.
- The review’s vintage/wine should match the notebook’s parent vintage (validation).
- Do not automatically overwrite reviews, publish them, or delete them when links are removed.
- **Implemented behavior:** `POST
  /api/v1/article_projects/:article_project_id/article_project_vintages/:article_project_vintage_id/notebooks/:notebook_id/review`
  creates a `draft` review with the notebook title/content, its parent vintage,
  the current user, and the required default score of `80`. The review and its
  `ArticleProjectReview` link are created in one transaction, so an association
  failure rolls the review back instead of requiring a retry flow.
- The resulting review is independently editable through `ReviewForm`; later
  notebook edits do not overwrite copied review content. The existing project
  review links remain visible in the detail page.
- **Not implemented in this slice:** a separate retry UI for a partial
  create/link failure (not needed for the atomic endpoint), a new
  notebook-to-review join model, and a dedicated in-workspace action to add a
  linked review to an article.