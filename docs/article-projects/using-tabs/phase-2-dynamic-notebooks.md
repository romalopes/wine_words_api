# Phase 2 — Dynamic notebooks

## Goal
Add rich-text notebooks to each vintage in the Wines & Notes tab, allowing users to create, edit, delete, and reorder notebooks per vintage.

## Description
- Extend the Wines & Notes tab to include a notebook manager for each vintage:
  - Each notebook has a title and rich-text content (using the existing `RichTextEditor` from `ArticleForm`).
  - Users can add, edit, delete, and reorder notebooks (via drag-and-drop or arrow buttons).
  - Notebooks are persisted to the backend via new API endpoints.
- Backend changes:
  - Create `ArticleProjectNotebook` model (belongs_to :article_project_vintage, with `title:string` and `content:text`).
  - Implement RESTful endpoints for notebooks nested under vintages:
    - `GET    /article_projects/:id/article_project_vintages/:vintage_id/notebooks`
    - `POST   /article_projects/:id/article_project_vintages/:vintage_id/notebooks`
    - `GET    /article_projects/:id/article_project_vintages/:vintage_id/notebooks/:notebook_id`
    - `PATCH  /article_projects/:id/article_project_vintages/:vintage_id/notebooks/:notebook_id`
    - `DELETE /article_projects/:id/article_project_vintages/:vintage_id/notebooks/:notebook_id`
  - Add serializer for notebooks (optional inclusion in vintage serializer).
  - Ensure proper authentication and authorization (only project owners/collaborators can manage notebooks).
- Frontend changes:
  - Add TypeScript interfaces for notebook objects.
  - Extend `articleProjectsApi` service with notebook CRUD methods.
  - In the Wines & Notes tab, for each vintage show:
    - List of notebooks (title and excerpt).
    - Controls to add a new notebook.
    - Inline editing for title and content (using `RichTextEditor`).
    - Delete and reorder controls.
  - Ensure notebook content is saved independently and survives tab switches and reloads.

## Acceptance Criteria
- User can add multiple notebooks per vintage, each with a title and rich-text content.
- Notebook edits are preserved when switching tabs or reloading the page.
- Notebooks can be reordered (e.g., drag-and-drop or up/down arrows).
- Deleting a notebook removes it permanently.
- Existing wine tracking (vintage attributes, logistics notes) remains unchanged and functional.
- API endpoints return correct data and enforce permissions.

## Notes
- This phase does not include reviews integration (that comes in Phase 3).
- The existing single-line `notes` field on vintages (for logistics) is untouched.