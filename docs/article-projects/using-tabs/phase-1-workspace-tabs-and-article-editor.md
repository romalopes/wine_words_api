# Phase 1 — Workspace tabs and embedded Article editor

## Goal
Turn Article Projects into an editorial workspace organised into three tabs:
1. **Overview:** basic information and the project dashboard.
2. **Article:** the existing Article component, embedded for creating and editing.
3. **Wines & Notes:** wine tracking (existing functionality only in this phase).

## Description
- Implement a tabbed interface (Overview, Article, Wines & Notes) within the Article Project detail/view page.
- Preserve the existing project workflow and data.
- Overview tab:
  - Display basic information (Assignment, Contact, Workflow, Targets).
  - Reuse the existing dashboard to show deadline, editor, word counts, wine counts, etc.
  - Make dashboard cards navigable (e.g., clicking tasted-wine count opens Wines & Notes tab with the “Tasted” filter).
- Article tab:
  - Embed the existing `ArticleForm` component.
  - If no article is linked, show buttons to create a new article or link an existing one.
  - If an article is linked, display the `ArticleForm` pre-populated with the article’s data.
  - Provide actions to save the article, preview, and unlink.
  - After article save, refresh server-derived word counts in the Overview dashboard.
- Wines & Notes tab (Phase 1 only):
  - Display the existing wine tracking section (vintages) as it appears in the current `ArticleProjectDetail`.
  - Keep the existing single-line `notes` field (logistics notes) intact.
  - Do not add notebooks or reviews integration in this phase.

## Acceptance Criteria
- User can switch between tabs without losing unsaved work (form state preserved).
- Overview dashboard shows correct data and updates after article save.
- Article tab allows creating, editing, and linking articles.
- Wines & Notes tab displays existing vintages and logistics notes as before.
- Existing project workflows (e.g., creating a project, adding vintages, producers) remain functional.

## Notes
- This phase focuses on the workspace structure and embedding the article editor.
- Dynamic notebooks and reviews integration will be added in later phases.