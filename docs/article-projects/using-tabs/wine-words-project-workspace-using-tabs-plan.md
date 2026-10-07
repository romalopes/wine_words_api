# Wine Words — Article Project Workspace Plan

Date: 7 October 2026

> **Implementation status update — October 7, 2026:** This remains the target
> workspace plan. The repository currently has a delivered vertical slice in
> the existing Article Project detail page: per-vintage notebook CRUD,
> optimistic-lock conflict recovery, atomic notebook-to-draft-review creation,
> and linked-review editing. It does **not** yet implement the complete
> URL-backed tab workspace, embedded `ArticleForm`, notebook reordering, or all
> verification scenarios specified below. Treat the phase prompts as design and
> acceptance requirements unless a phase document explicitly records an
> implementation result.

## 1. Goal

Turn Article Projects into an editorial workspace organised into three tabs:

1. **Overview:** basic information and the project dashboard.
2. **Article:** the existing Article component, embedded for creating and editing.
3. **Wines & Notes:** wine tracking, dynamic notebook subtabs, and Reviews integration.

Deliver this incrementally, preserving the existing project workflow and data.

## 2. Repository baseline

This plan is based on the repository inspection completed in this conversation:

- API: https://github.com/romalopes/wine_words_api
- Frontend: https://github.com/romalopes/wine_words_front_end

Reinspect the current branch before implementation; the repositories may have changed.

| Existing implementation | Planned reuse |
|---|---|
| ArticleProjectForm | Split its current sections across the tabs |
| ArticleProjectDetail | Reuse dashboard and progress indicators |
| ArticleForm with RichTextEditor | Embed in the Article tab |
| ArticleProjectVintage | Keep wine selection, receipt and tasting tracking |
| ArticleProjectProducer | Keep outreach and producer notes |
| ArticleProjectReview | Keep supporting review associations |
| ReviewForm with RichTextEditor | Embed for linked review creation and editing |
| Project lock_version | Preserve concurrent-edit protection |

The current project form links an article rather than editing it. Wine notes currently use single-line inputs. The project serializer returns an article summary rather than its full editable content.

Existing relationships:

- ArticleProject belongs to its creator through User.
- ArticleProject optionally belongs to an Article.
- ArticleProject has many producers through ArticleProjectProducer.
- ArticleProject has many vintages through ArticleProjectVintage.
- ArticleProject has many reviews through ArticleProjectReview.

Retain these relationships. Do not create a duplicate project-to-wine relationship.

## 3. Overview tab

### Basic information

| Area | Fields |
|---|---|
| Assignment | Name, publication, description |
| Contact | Editor name and email |
| Workflow | Assignment status and drafting status |
| Targets | Deadline and target word count |

Preserve existing project and drafting status values.

### Dashboard

Reuse the existing dashboard to show:

- Deadline and overdue warning.
- Editor and project owner.
- Actual words versus target.
- Remaining words.
- Total wines.
- Requested, received, selected and tasted wine counts.
- Progress towards the target word count.

Keep target word count editable. Actual word count is derived from the linked article body.

Dashboard cards should support navigation. For example, clicking the tasted-wine count opens Wines & Notes with the corresponding filter.

After an article save, refresh server-derived word counts. Preserve any unsaved project fields while updating dashboard data.

## 4. Article tab

### No linked article

Offer:

- **Create article:** open ArticleForm inside the workspace, defaulting to draft.
- **Link existing article:** reuse existing article lookup.

### Linked article

Fetch the full article using the existing article API and embed ArticleForm.

Provide:

- Save article.
- Preview.
- Unlink article.

Reuse rich text, images, vintage selection and review linking already implemented by ArticleForm.

### Behaviour

- Saving stays inside the workspace.
- Refresh project word counts after saving.
- Unlinking preserves the article itself.
- Publication remains an explicit action.
- Ordinary project saves never publish content.
- Check article edit permissions independently from project access.
- Preserve standalone ArticleForm behaviour.
- Do not silently synchronise project vintages or project reviews with article associations.
- Provide explicit actions to add selected project vintages or reviews to the article.

### Creation and linking reliability

If article creation succeeds but linking it to the project fails, retain the created article ID and show a retry action. Retrying must link that same article rather than create another.

Use the refreshed project lock_version when linking. A project concurrency conflict must preserve the created article and the user's work.

## 5. Wines & Notes tab

Use two areas: wine tracking and dynamic notebook subtabs.

### Wine and producer tracking

Retain:

- Producer lookup.
- Contacted and request-confirmed flags.
- Producer outreach notes.
- Vintage lookup.
- Requested, received, selected and tasted flags.
- Date received.
- Bottle condition.
- Existing wine logistics notes.

Use ArticleProjectVintage as the wine association. This distinguishes different vintages of the same wine.

Preserve existing receipt consistency validation, including date and bottle-condition rules.

### Dynamic notebooks

Allow users to create, rename, reorder and delete notebook subtabs.

| Example | Purpose |
|---|---|
| Research | General story research and sources |
| Producer interview | Interview notes |
| Shiraz 2023 | Notes associated with a selected vintage |
| Second tasting | Another notebook for the same vintage |
| Conclusions | Comparisons and article ideas |

Each notebook includes:

- Title.
- Rich text body.
- Optional project vintage association.
- Author.
- Last saved time.
- Saved/unsaved indicator.

Support multiple notebooks for a single vintage and notebooks without a wine association.

Avoid another level of nested tabs. On smaller screens, offer a searchable notebook selector. Use stable persisted IDs for notebook selection rather than tab labels.

Existing producer and vintage notes remain logistics remarks. Do not overwrite or automatically convert them into new notebook content.

## 6. Reviews integration

Integrate Reviews into Wines & Notes while keeping notebooks independent from formal reviews.

| Action | Result |
|---|---|
| Link existing review | Attach an accessible review for the selected vintage |
| Create review from note | Open ReviewForm with the vintage and copied notebook text |
| Edit linked review | Open the existing review editor in the workspace |
| Add review to article | Explicitly use the existing article-review relationship |

Rules:

- New reviews default to draft.
- Users complete required review fields before saving.
- Copy notebook content only through an explicit action.
- Later notebook edits do not overwrite reviews.
- Editing a review does not overwrite its source notebook.
- Deleting a notebook or removing a review link preserves the review.
- Validate vintage matching for wine-associated notebooks.
- Enforce review ownership and editing permissions independently of project access.
- Preserve existing project review links, including links without notebooks.
- Do not publish reviews automatically.

If creating a review succeeds but project linking fails, offer a retry using the saved review ID. Do not create duplicate reviews.

## 7. Proposed data model

### ArticleProjectNote

Add an article_project_notes table:

| Field | Purpose |
|---|---|
| article_project_id | Required parent project |
| article_project_vintage_id | Optional association with a project vintage |
| title | Notebook subtab label |
| body | Rich text in the existing editor's compatible format |
| position | Subtab order |
| created_by_id | Author, following the current User relationship |
| lock_version | Concurrent-edit protection |
| created_at / updated_at | Timestamps |

Validation and indexing:

- Require project, author and a nonblank title.
- Validate that any selected project vintage belongs to the same project.
- Add foreign keys.
- Index project and ordering fields.
- Set deterministic ordering using position and ID.
- Use existing sanitization conventions when storing and rendering rich text.
- Choose content and title limits after checking repository conventions.

### Optional notebook-to-review relationship

Add article_project_note_reviews if notebooks need explicit review associations:

- article_project_note_id.
- article_project_review_id.
- Timestamps.
- Unique index on the pair.
- Foreign keys.
- Validation that both records belong to the same project.

This connects notebooks to the existing project-review association rather than duplicating review content.

### Deletion rules

- Project deletion removes its notebooks and project association records.
- Notebook deletion removes notebook-review associations but preserves Reviews.
- Removing a project-review association removes its notebook associations but preserves the Review.
- Removing a project vintage should detach associated notebooks from that vintage, preserving their content; explain this consequence in the UI.
- Existing Article and Review records must survive project deletion.

Confirm existing association deletion behaviour before applying these changes.

## 8. API and authorization

Add project-scoped notebook CRUD and reorder operations following existing routing conventions.

Illustrative routes, to confirm during implementation:

| Operation | Proposed route under /api/v1 |
|---|---|
| List / create notes | /article_projects/:project_id/notes |
| Read / update / delete note | /article_projects/:project_id/notes/:id |
| Reorder notes | /article_projects/:project_id/notes/reorder |

Requirements:

- Resolve every notebook through the authorized parent project.
- Reject cross-project vintage and review IDs.
- Enforce the existing project ownership and role rules.
- Preserve Reviewer CRUD access to their own projects.
- Verify manager access through existing role helpers rather than introducing a parallel role system.
- Require the appropriate lock_version for notebook updates.
- Return a recoverable conflict for stale writes.
- Reorder atomically and verify that all supplied note IDs belong to the project.
- Use an ordering concurrency guard so simultaneous reorder requests do not silently overwrite each other.
- Keep response types and frontend API services consistent.
- Fetch full article and review content through their own authorized APIs.

The existing project authorization uses wine_manager? for creation and catalogue_manager? for broader project access. Recheck their definitions before changing any policy.

## 9. Creation, editing and saving

### New project

1. Show the three-tab workspace.
2. Enter basic details in Overview.
3. Select Create project.
4. Remain in the workspace.
5. Enable full Article and Wines & Notes functionality.

Before the first save, the other tabs show clear empty states with a Create project to continue action.

### Existing project

Save project details, articles, notebooks and reviews independently.

- Use separate forms; never nest ArticleForm or ReviewForm inside the project form.
- Preserve unsaved state when switching tabs.
- Track dirty state separately for each editing area.
- Show clear save indicators.
- Preserve existing unload and navigation protection.
- Keep the active tab in URL query parameters.
- Handle missing or deleted notebook IDs by selecting a valid fallback.
- Update local lock versions after each successful save.
- Present conflicts without automatically discarding local work.
- Load embedded editors only when needed without losing their draft state.

Start with explicit saves. Autosave can be introduced later after concurrency and recovery behaviour is reliable.

## 10. Implementation phases and AI prompts

Run the following prompts in order. Each phase should inspect the current implementation, make the requested change, run relevant checks and report results.

### Phase 1 — Workspace tabs

```text
Inspect the existing ArticleProjectForm, ArticleProjectDetail, API types,
services, routes and tests.

Refactor Article Projects into a shared workspace with three tabs:
Overview, Article, and Wines & Notes.

Reuse the existing dashboard, project fields, producer tracking,
vintage tracking and review links. Preserve the current API contract,
permissions, lock_version handling and existing data.

Keep the tab in URL query parameters and preserve unsaved state when
switching tabs. Use accessible tab navigation and separate forms.

Keep create/edit/detail routes working. Before initial creation, show
clear empty states in Article and Wines & Notes. After creation, remain
in the workspace and enable these sections.

Do not introduce database changes in this phase.
```

Acceptance criteria:

- Existing projects still render.
- Dashboard and all existing form fields remain available.
- Switching tabs does not discard edits.
- Browser navigation and refresh preserve the selected tab.
- Tabs work with keyboard navigation and on mobile.

### Phase 2 — Embedded Article editor

```text
Embed the existing ArticleForm in the Article Project workspace.
Support creating a draft, linking an existing article, editing, previewing
and unlinking.

Fetch the full article through its existing API. Reuse RichTextEditor and
the existing save/cancel callbacks. Saving must stay in the workspace and
refresh project word-count statistics without discarding other edits.

Check article permissions independently from project permissions.
Preserve standalone ArticleForm behaviour.

Make article creation and project linking recoverable: if linking fails,
retain the created article ID and offer retry without creating duplicates.
Use the latest project lock_version.

Do not publish automatically or silently synchronise project associations
with article associations. Provide explicit add-to-article actions.
```

Acceptance criteria:

- Draft creation and existing article linking both work.
- Article editing stays within the workspace.
- Saved article content updates dashboard word counts.
- Unlinking preserves the Article.
- A failed link can be retried without duplicate creation.

### Phase 3 — Dynamic notebooks

```text
Add ArticleProjectNote with project, optional project vintage, title,
rich text body, position, author, timestamps and optimistic locking.

Provide project-scoped CRUD and reorder endpoints. Enforce project
authorization and validate same-project vintage associations. Reorder
atomically with a concurrency guard.

Build dynamic notebook subtabs in Wines & Notes using the existing
RichTextEditor. Support general notes and multiple notes per vintage,
rename, reorder, delete, dirty-state preservation and save indicators.

Preserve existing producer and vintage notes as logistics remarks.
Apply existing content sanitization conventions to notebook content.

Removing a project vintage must preserve notebook content by detaching
the vintage association. Keep active notebook selection valid after
deletion and use a searchable selector on smaller screens.
```

Acceptance criteria:

- Notes survive refresh with their titles, bodies and order.
- Multiple notes can reference one vintage.
- General notes need no wine association.
- Cross-project associations are rejected.
- Stale writes produce a recoverable conflict.
- Existing logistics notes remain intact.

### Phase 4 — Reviews integration

```text
Reuse ArticleProjectReview and ReviewForm to support linking existing
reviews, creating draft reviews from notebook content, and editing linked
reviews within Wines & Notes.

If needed, add a notebook-to-project-review join model with uniqueness
and same-project validation.

Validate vintage matching for wine-associated notebooks. Enforce existing
review ownership and editing permissions independently of project access.

Copy note content only through an explicit action. Never automatically
overwrite reviews, publish them, or delete them when links are removed.
Keep existing project review links visible.

If review creation succeeds but association fails, retain the saved
review ID and offer a retry without duplicate creation.

Keep adding a project review to the article an explicit separate action.
```

Acceptance criteria:

- Reviews created from notes default to draft.
- Required fields are validated before saving.
- Notebook and review content remain independently editable.
- Existing unassociated project review links remain visible.
- Unlinking or deleting notes preserves Review records.

### Phase 5 — Verification

```text
Extend existing frontend tests and Rails request specs.

Verify tab switching preserves edits; saving refreshes lock versions;
article save updates dashboard word counts; notebooks survive reload;
multiple notebooks can reference one vintage; and concurrent saves
produce a recoverable conflict.

Test Reviewer access to their own projects and denial of unauthorized
cross-project access. Test article/review permissions separately.

Verify review creation defaults to draft, linking retries cannot create
duplicates, unlinking preserves content, and existing project records
still render correctly.

Test notebook reorder concurrency, removing a project vintage while
preserving notebook content, and project deletion while preserving
Article and Review records.

Run the repository's relevant checks and verify the complete workflow
at desktop and mobile widths. Report checks run, results and remaining
limitations.
```

## 11. End-to-end acceptance scenario

1. A Reviewer creates their own Article Project with a target of 1,500 words.
2. They add producers and several wine vintages.
3. They record sample receipt and bottle condition.
4. They create a Research notebook and two tasting notebooks for one vintage.
5. They switch tabs without losing unsaved work.
6. They create and save an Article draft in the Article tab.
7. Overview shows the saved article's actual and remaining word counts.
8. They explicitly create a draft Review from a tasting notebook.
9. They edit the Review independently and link it to the project.
10. They explicitly add that Review to the Article.
11. They refresh and recover the saved workspace and notebook order.
12. Another account cannot access the project without existing authorization.
13. Concurrent edits produce a visible, recoverable conflict.
14. Unlinking content or deleting the project preserves Article and Review records.

## 12. Recommended delivery order

First deliver the workspace tabs and embedded Article editor. Then add dynamic notebooks and Reviews integration. Finish with focused workflow, authorization, concurrency and mobile verification.

This provides a useful improvement early while extending the existing implementation rather than replacing it.

