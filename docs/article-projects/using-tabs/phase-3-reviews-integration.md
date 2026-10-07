# Phase 3 — Reviews integration

## Goal
Integrate review creation and editing within the Wines & Notes tab, allowing users to create draft reviews from notebook content and link existing reviews to the project.

## Description
- From any notebook in the Wines & Notes tab, provide an action “Create draft review from this notebook”:
  - Opens a form (reusing `ReviewForm` or similar) pre‑populated with the notebook’s title and content.
  - The review defaults to “draft” status.
  - User can edit the review independently and then save it.
  - After saving, offer to link the review to the project (or link automatically if preferred).
- Allow linking existing reviews to the project (reusing existing lookup functionality) and editing linked reviews within the Wines & Notes tab.
- Ensure notebook content and review content remain independently editable (acceptance criterion).
- Backend changes:
  - Add a custom action to create a review from a notebook:
    - `POST /article_projects/:id/article_project_vintages/:vintage_id/notebooks/:notebook_id/review`
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