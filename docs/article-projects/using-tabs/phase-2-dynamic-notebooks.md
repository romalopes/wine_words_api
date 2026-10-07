# Phase 2 — Dynamic notebooks

> **Status:** Core CRUD implemented; follow-up requirements remain (October 7, 2026).

## Goal
Add rich-text notebooks to each vintage in the Wines & Notes area, allowing users to create, edit, delete, and eventually reorder notebooks per vintage.

## Description
- Extended the Wines & Notes area to include a notebook manager for each vintage:
  - Each notebook has a title and rich-text content using the existing
    `RichTextEditor` from `ArticleForm`.
  - Users can add, edit, and delete notebooks.
  - Notebooks are persisted through project-vintage nested API endpoints.
- Backend changes:
  - Created `ArticleProjectNotebook` (belongs to `ArticleProjectVintage`) with
    `title`, rich-text `content`, `position`, timestamps, and optimistic-lock
    `lock_version`.
  - Implemented RESTful endpoints for notebooks nested under vintages:
    - `GET    /article_projects/:id/article_project_vintages/:vintage_id/notebooks`
    - `POST   /article_projects/:id/article_project_vintages/:vintage_id/notebooks`
    - `GET    /article_projects/:id/article_project_vintages/:vintage_id/notebooks/:notebook_id`
    - `PATCH  /article_projects/:id/article_project_vintages/:vintage_id/notebooks/:notebook_id`
    - `DELETE /article_projects/:id/article_project_vintages/:vintage_id/notebooks/:notebook_id`
  - The project serializer includes notebooks in each vintage payload.
  - Notebook routes use the project-vintage join ID and enforce the existing
    project authorization boundary: project creators may manage their own
    projects; catalogue managers may manage all projects. Unauthorized access
    is returned as not found.
- Frontend changes:
  - Added TypeScript interfaces for notebook objects.
  - Extended `articleProjectsApi` service with notebook CRUD methods.
  - For each vintage, the detail page shows notebook titles plus controls to
    add, edit, delete, and create a draft review.
  - Inline editing uses `RichTextEditor`; saved notebook content is returned in
    the project-detail payload after reload.

## Acceptance Criteria
- User can add multiple notebooks per vintage, each with a title and rich-text content.
- Notebook edits persist after save and page reload.
- Stale notebook updates and deletes return a recoverable `409 Conflict` using
  `lock_version`; the editor retains local input and offers a reload action.
- Deleting a notebook removes it permanently.
- Existing wine tracking (vintage attributes, logistics notes) remains unchanged and functional.
- API endpoints return correct data and enforce permissions.

## Notes
- This phase does not include reviews integration (that comes in Phase 3).
- The existing single-line `notes` field on vintages (for logistics) is untouched.
- **Not implemented in the current slice:** general (non-vintage) notebooks,
  notebook reordering, notebook subtabs/search selector, detaching notebook
  content when a project vintage is removed, and a rendered notebook-content
  preview. These remain follow-up work rather than completed behavior.