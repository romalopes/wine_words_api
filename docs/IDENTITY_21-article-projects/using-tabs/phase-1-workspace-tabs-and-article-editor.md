# Phase 1 — Workspace tabs and embedded Article editor

> **Status:** Partially implemented as of October 7, 2026. The current product
> retains the Article Project detail and edit workflows, but does not yet provide
> the full URL-backed three-tab workspace or embedded `ArticleForm` described
> below. This document remains the design target for that work.

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
  - Note: Dashboard cards are not yet navigable (click-to-filter functionality will be added in a future update).
- Article tab:
  - Embed the existing `ArticleForm` component.
  - If no article is linked, show buttons to create a new article or link an existing one.
  - If an article is linked, display the `ArticleForm` pre-populated with the article’s data.
  - Provide actions to save the article, preview, and unlink.
  - After article save, the project data is refreshed to show updated server-derived word counts in the Overview dashboard.
- Wines & Notes tab (Phase 1 only):
  - Display the existing wine tracking section (vintages) as it appears in the current `ArticleProjectDetail`.
  - Keep the existing single-line `notes` field (logistics notes) intact for vintages, producers, and reviews.
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
- Dashboard card navigation (clicking counts to filter) is planned for a future enhancement.
- The later notebook/review work was delivered in the existing
  `ArticleProjectDetail` view rather than in a separate tab workspace, so it
  does not imply completion of the tab and embedded-article requirements here.