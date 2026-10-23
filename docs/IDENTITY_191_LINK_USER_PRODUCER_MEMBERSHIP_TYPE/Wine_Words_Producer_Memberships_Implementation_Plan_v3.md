# Wine Words — User Detail & Producer Memberships (v3)

**Date:** 23 October 2026  
**Scope:** Producer membership administration and member-authorized Producer editing **only**  
**API repository:** https://github.com/romalopes/wine_words_api  
**Frontend repository:** https://github.com/romalopes/wine_words_frontend  
**Relevant routes:** `/users`, `/users/:id`, `/account`, existing Producer edit routes

> **Important scope decision:** `follower` is **not** a Producer membership type. Do **not** create `Follow`, `follows`, polymorphic followables, follow/unfollow endpoints, buttons, counts, or notifications in this implementation. Following Producers, Wines, Articles, and Reviews is a **separate future feature**. This document supersedes the earlier membership/following plan.

> **Repository verification:** This is an implementation specification, not a verified audit of the latest repository code. The AI assistant implementing it must inspect existing models, migrations, controllers, policies, routes, serializers, tests, React routes, and components first. Adapt naming and API paths to actual conventions rather than blindly introducing duplicates.

## 1. Goals and non-goals

### Goals

1. Replace the editing-heavy `/users` cards with a searchable user directory and link each user to `/users/:id`.
2. Allow Admin and Editor to view `UserDetail` and manage the user's existing **global roles** and **subscription**, respecting current permissions.
3. Add Producer memberships to `UserDetail`: search existing Producers, assign `owner`, `manager`, or `contributor`, change type, and unlink.
4. Support a true many-to-many relationship: many users per Producer and many Producers per user, with at most one membership per user/Producer pair.
5. Show associated Producers on `/account`, with edit links/actions only when authorized.
6. Reuse the existing Producer editor, APIs, search controls, RBAC patterns, and validation wherever possible.
7. Keep Producer membership types distinct from global Admin/Editor/Reviewer/Reader roles.

### Explicitly out of scope

- `follower` membership type or any `viewer` type.
- Any Follow model, polymorphic Follow relationship, Follow/Unfollow UI or API, social feeds, notifications, follower counts.
- Invitations, ownership verification, Producer deletion by members, member-managed membership administration, automatic subscription changes.
- A new global role system or subscription model.

## 2. Domain model

### Membership types

| `membership_type` | Meaning | Edit Producer profile | Manage memberships |
|---|---|---|---|
| `owner` | Responsible representative of the Producer in Wine Words; not proof of legal ownership | Yes | No, in this release |
| `manager` | Authorized manager of Producer details | Yes | No |
| `contributor` | Associated contributor, potentially eligible for scoped content features later | No general Producer edit by default | No |

**Important:** Membership is an authorization/business relationship, not a social follow. Owners/Managers do not automatically follow anything. No default membership type: Admin/Editor must choose deliberately.

### Schema (fresh, not-yet-applied migration)

```ruby
class CreateProducerMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :producer_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :producer, null: false, foreign_key: true
      t.string :membership_type, null: false
      t.references :created_by, null: true,
                   foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end

    add_index :producer_memberships, [:user_id, :producer_id], unique: true
    add_check_constraint :producer_memberships,
                         "membership_type IN ('owner', 'manager', 'contributor')",
                         name: "producer_memberships_type_check"
  end
end
```

If the current project uses a different identity table or migration version, follow the repository. The unique database index is required even with model validation. If migrations have been applied anywhere shared, **do not edit historical migrations**: add a new forward migration.

### Rails model (adapt to existing code)

```ruby
class ProducerMembership < ApplicationRecord
  belongs_to :user
  belongs_to :producer
  belongs_to :created_by, class_name: "User", optional: true

  enum :membership_type, {
    owner: "owner",
    manager: "manager",
    contributor: "contributor"
  }

  validates :membership_type, presence: true
  validates :user_id, uniqueness: { scope: :producer_id }
end
```

**User:** `has_many :producer_memberships, dependent: :destroy` and `has_many :producers, through: :producer_memberships` (check existing associations first).  
**Producer:** `has_many :producer_memberships, dependent: :destroy` and `has_many :users, through: :producer_memberships`.

Do not change or rename any global `role` field: only the join model uses `membership_type`.

### Existing database upgrade scenarios

Before migration, inspect schema and data; record counts grouped by existing role/type, null values, duplicates, indexes, and constraints.

1. **Migration not applied anywhere:** change the pending create migration to the final schema above.
2. **Column named `role` already exists:** rename to `membership_type` in a new migration if appropriate; update enum code and constraints.
3. **`membership_type` already exists and contains `follower` or legacy `viewer`:** **do not silently delete, convert to contributor, or elevate privileges**. Inventory and export those rows, determine whether they represent actual user-initiated follows or test data, obtain an explicit retention/removal decision, then remove/migrate them in a separate controlled data migration before enforcing the new constraint. If follow data must be preserved, defer destructive cleanup until a separate Follow feature exists or archive/export securely under approved retention policy.
4. **Old default `follower`/`viewer`:** remove the default, enforce `NOT NULL`, and replace any existing check constraint with the three allowed types after data cleanup.
5. **Legacy untyped rows:** resolve individually or through an approved mapping; never automatically grant `owner` or `manager` access.

Include a verified rollback strategy and backup before production migration. A downgrade must not reintroduce invalid values.

## 3. Authorization policy

| Operation | Global Admin | Global Editor | Owner | Manager | Contributor | Other user |
|---|---|---|---|---|---|---|
| View `/users` and `/users/:id` | Yes | Yes | No | No | No | No |
| Edit global roles | Existing policy; Admin-only for Admin role | Existing policy; cannot grant/revoke Admin | No | No | No | No |
| Change subscriptions | Existing policy | Existing policy | No | No | No | No |
| Add/change/remove memberships | Yes | Yes, subject to sensitive-role restrictions | No | No | No | No |
| Edit Producer profile | Yes | Yes | Yes | Yes | No by default | No |
| View associated Producers in own account | Yes | Yes | Yes | Yes | Yes | Own only |

**Security requirements:** Authorize on every backend endpoint, not just React. Derive acting user from authentication; never accept client-supplied `created_by_id`. Validate target user and Producer exist. Prevent unauthorized ID enumeration and privilege escalation. Reuse existing policy layer (e.g. Pundit/CanCan/custom). Restrict Admin role modification by Editors. If assigning `owner` is considered sensitive, limit that operation to Admin only; decide during audit and document it. Enforce last-owner protection **only if** the business requires every Producer to have an owner; use transaction/locking to avoid races. Keep audit information (actor and timestamps) for changes where practical.

## 4. Backend API contract (illustrative)

Follow existing namespace, serialization, pagination, errors and authentication conventions. Suggested endpoints:

```http
GET    /api/v1/users/:user_id/producer_memberships
POST   /api/v1/users/:user_id/producer_memberships
PATCH  /api/v1/users/:user_id/producer_memberships/:id
DELETE /api/v1/users/:user_id/producer_memberships/:id
GET    /api/v1/account/producer_memberships
```

Existing `/api/v1/producers` search should be reused if suitable. Optionally expose memberships nested under Producers for existing admin workflows, but avoid redundant write paths without a need.

**Create request:**

```json
{ "producer_membership": { "producer_id": 42, "membership_type": "manager" } }
```

**Update request:**

```json
{ "producer_membership": { "membership_type": "owner" } }
```

**Response fields:** membership `id`, `user_id`, `producer_id`, `membership_type`, `created_at`, `updated_at`, plus minimally necessary Producer summary (name, slug/id) and creator metadata for Admin/Editor as permitted. Never expose sensitive user fields unnecessarily.

Return conventional statuses: 201 create; 200 update; 204 delete; 401 unauthenticated; 403 unauthorized; 404 missing or concealed resource; 409 duplicate; 422 validation failure. Handle unique-index races and concurrent updates safely. An invalid `follower` or `viewer` value must fail with a clear validation error. Membership mutation must never create a Follow record.

## 5. Frontend requirements

### `/users` — Admin/Editor directory

- Show name, email, global role badges, subscription, optional Producer membership count, and `View details` link to `/users/:id`.
- Keep search/filter/sort/pagination and existing loading/empty/error states.
- Remove inline global-role checkbox editing and subscription editing from list cards; move to `UserDetail`.
- Restrict access using existing route guard **and** backend authorization.

### `/users/:id` — UserDetail

Three independent sections:

1. **User & global roles:** existing role checkboxes and Save Roles logic, preserving self-Admin protection and Editor restrictions.
2. **Subscription:** existing subscription picker and update action, without coupling changes to membership saves.
3. **Producer memberships:** list Producer name/link, membership type badge/select, creation metadata if appropriate, `Change type`, and `Remove`. Add Producer via reusable searchable selector, with explicit membership type choice. Confirm destructive unlink and show mutation feedback. No `follower` option.

UX: disable duplicate Producer selection; handle missing/deleted Producers, empty lists, slow search, pagination, stale state and 403/409/422 responses. Do not overwrite unsaved global-role changes when updating a membership. Add accessible labels and keyboard navigation.

### Reusable `ProducerSearchSelect`

- Inspect existing Producer search component first; reuse/extend it rather than duplicating it.
- Debounced server search with result IDs, names, and distinguishing metadata (region if available).
- Supports selection of a single Producer, excludes already-linked Producers, and handles empty results.
- Separate the selector from membership-type selection so it can be reused elsewhere.

### `/account` — My Producers

- Add `My Producers` section showing Producer, `membership_type`, and link to details.
- Show `Edit Producer` only to Owner/Manager or globally authorized Admin/Editor; Contributor can view association but does not get generic edit access.
- Reuse the existing Producer edit page/component; do not build a parallel editing form.
- Membership users cannot change their own membership type or link other users here.
- No `Following` section in this release.

### Producer detail pages

- No Follow/Unfollow controls as part of this project.
- Existing Producer detail/edit page may show membership-based `Edit` affordance for authorized Owner/Manager, subject to current UI conventions.
- Preserve public read access and existing Producer slug resolution; handle unknown slugs with not-found behavior.

## 6. Implementation phases and AI prompts

Execute phases in order. For every phase: inspect before editing, report actual files changed, run relevant tests/lint, and describe assumptions or deviations. Do not commit or deploy without explicit instruction.

### Phase 0 — Repository audit and design alignment

**Tasks:** Inspect both repos for `User`, `Producer`, membership migrations, global role assignment, subscription controller, existing search component, Producer editing authorization, API namespace, React routing, and tests. Determine which migrations have run in development/staging/production. Document exact file paths, endpoints and migration state.

**AI prompt — audit (both repos):**

> Inspect Wine Words API and frontend. Identify the current implementation of `/users`, `/account`, Producer detail/edit pages, global roles, subscriptions, authentication, authorization, Producer search and any ProducerMembership schema. Produce a concise file-by-file implementation map and highlight schema/data migration hazards. Do not modify code. Target only membership types owner/manager/contributor; follower and polymorphic Follow are explicitly out of scope. Recommend how to reuse existing components and policies.

**Done when:** implementation map and migration decision are documented; no unverified assumptions remain.

### Phase 1 — Schema and data migration

**Tasks:** Implement/upgrade `producer_memberships` with `membership_type` string enum values owner/manager/contributor, unique user/Producer index, creator FK, and DB check constraint. Remove old follower default and resolve any legacy follower/viewer data safely. Include schema and rollback verification.

**AI prompt — backend:**

> Based on the repository audit, implement ProducerMembership persistence in Rails 8.x. The attribute must be `membership_type`, not `role`; only owner, manager and contributor are valid. No default membership type. Use a unique composite index, correct foreign keys and DB constraint. If the migration was applied, add a forward migration; never rewrite applied history. Inventory existing follower/viewer rows and stop for a data-retention decision before destructive changes. Add model and migration tests; run them and report results.

**Done when:** schema matches requirements, migration is safe for the actual DB state, and model tests pass.

### Phase 2 — Model associations and authorization

**Tasks:** Add model associations, scopes/helpers if useful, global Admin/Editor membership administration policy, and Owner/Manager Producer editing policy. Contributor remains read-only for Producer details until a content-specific permission exists.

**AI prompt — backend:**

> Implement and test ProducerMembership model associations and policy rules using the application's existing authorization system. Admin/Editor may manage membership links; apply existing restrictions to sensitive actions. Owner and Manager may edit only their associated Producer profiles; Contributor may not edit general Producer details. Memberships must not affect global roles or subscriptions. Never add follower logic. Add tests for cross-Producer access, privilege escalation, and unauthorized changes.

**Done when:** policy tests demonstrate no access leakage.

### Phase 3 — Membership API

**Tasks:** Add list/create/update/delete endpoints for Admin/Editor, own-account read endpoint, strong params, serialization, pagination if needed, and proper error handling.

**AI prompt — backend:**

> Implement ProducerMembership REST endpoints following existing API conventions. Support Admin/Editor CRUD on a selected user's memberships, and authenticated read-only listing of one's own Producer memberships. Accept `membership_type` only from owner/manager/contributor, reject follower/viewer, enforce uniqueness, return appropriate 401/403/404/409/422 statuses, and derive `created_by` from the authenticated actor. Do not create follow endpoints. Add request specs for all permitted and forbidden scenarios, duplicate requests and invalid IDs.

**Done when:** API contract is documented and request tests pass.

### Phase 4 — Refactor `/users` and build `/users/:id`

**Tasks:** Make directory rows/cards navigable; move role checkbox controls and subscription editing to `UserDetail`. Preserve existing behavior, loading states and protections.

**AI prompt — frontend:**

> Refactor the Wine Words `/users` admin/editor page into a directory with links to `/users/:id`. Create `UserDetail` with separate global-role and subscription editing sections by reusing existing components/services. Preserve the current Admin self-role safeguard, Editor restrictions, API contracts and responsive styles. Do not change global role semantics. Add route guards, error/loading/404 states and component tests.

**Done when:** global role/subscription workflows work in UserDetail and directory no longer contains inline editing controls.

### Phase 5 — Producer membership management in UserDetail

**Tasks:** Reuse or build `ProducerSearchSelect`; show memberships; add Producer with required membership type; update type; unlink with confirmation; handle duplicate/error/empty states.

**AI prompt — frontend:**

> Extend `/users/:id` with a Producer Memberships section for Admin/Editor. Reuse the existing Producer search component if present; otherwise build a reusable accessible async `ProducerSearchSelect`. Allow linking an existing Producer with required `membership_type` owner/manager/contributor, editing the type and unlinking. Exclude already-linked Producers from search. Display membership badges and independent save/error states. Never show follower as an option, and do not add Follow UI. Add tests for success, 403, 409, 422, cancellation and pending requests.

**Done when:** complete Admin/Editor membership CRUD works from UserDetail.

### Phase 6 — `/account` My Producers and edit access

**Tasks:** List current user's memberships, display type, show Producer detail links, and authorize Edit for Owner/Manager only (plus existing global permissions). Reuse existing edit form.

**AI prompt — full stack:**

> Implement `/account` → `My Producers` using the authenticated account membership API. Show Producer name and membership_type; offer `Edit Producer` for owner/manager only, except users already globally authorized. Contributor should see the association but no generic Edit action. Enforce identical authorization in Rails Producer update endpoints and reuse the current Producer editing form. Do not add Following or Follow/Unfollow controls. Test both UI visibility and direct API access attempts.

**Done when:** members can see their Producers and only authorized users can edit.

### Phase 7 — Regression, security and migration QA

**Tasks:** Run Rails unit/request tests, frontend unit/integration tests, linters and builds. Test two users sharing one Producer, one user with multiple Producers, duplicate linking, concurrent requests, ownership changes, unknown Producer IDs, last-owner decision, Editor privilege escalation, and unlinked user access.

**AI prompt — QA:**

> Review all changes against the v3 Producer Membership plan. Add missing backend and frontend regression tests. Verify the only membership_type values are owner/manager/contributor across schema, enum, API, forms, fixtures, factories and seed data. Search for residual follower/viewer membership references and report them; do not remove unrelated code. Confirm no Follow feature was introduced. Test migration/rollback in a safe database, run lint/build/tests, and provide a pass/fail checklist with remaining risks.

**Done when:** tests pass, exceptions are documented, and no unauthorized Producer edits are possible.

### Phase 8 — Deployment and verification

**Tasks:** Backup production database; review existing data and migration status; deploy backend migration and API before frontend; verify Admin/Editor CRUD, Owner/Manager editing, Contributor restrictions, and account listing; monitor logs/errors; document rollback.

**AI prompt — release review:**

> Prepare a production rollout checklist for Wine Words ProducerMembership v3 based on actual deployment configuration. Include backup, migration preflight, data preservation decisions for any follower/viewer rows, backend-first release, frontend rollout, smoke tests, monitoring and rollback. Do not deploy or mutate production without explicit approval. No follow functionality is included.

**Done when:** release is verified against production acceptance criteria.

## 7. Manual acceptance checklist

- [ ] `/users` accessible only to authorized Admin/Editor; user links open `/users/:id`.
- [ ] `/users/:id` displays existing global roles and subscription controls independently.
- [ ] Editor cannot grant or revoke Admin role; existing self-Admin safeguard works.
- [ ] Admin/Editor can search and link an existing Producer to a user.
- [ ] Membership type selector contains exactly `owner`, `manager`, `contributor`.
- [ ] Admin/Editor can change type and unlink a membership with confirmation.
- [ ] Duplicate `(user_id, producer_id)` cannot be created, including concurrent requests.
- [ ] One Producer can have multiple users; one user can belong to multiple Producers.
- [ ] `/account` shows only the signed-in user's associated Producers.
- [ ] Owner and Manager can edit their associated Producer only.
- [ ] Contributor cannot edit general Producer details by default.
- [ ] Unlinked users cannot edit a Producer through direct API requests.
- [ ] Unknown/deleted Producer IDs and invalid membership types fail safely.
- [ ] Existing `follower`/`viewer` data, if any, was reviewed before schema tightening.
- [ ] No follower membership option, Follow model, Follow button or follow API is added.
- [ ] Existing global roles, subscriptions, Producer forms and unrelated functionality remain intact.

## 8. Future feature — intentionally deferred

A future, **separate** plan may introduce polymorphic `Follow` records (`user_id`, `followable_type`, `followable_id`) for Producer, Wine, Article and Review, with independent Follow/Unfollow and notification semantics. That work must not reuse or modify `ProducerMembership.membership_type`; it should remain independent so a Producer Owner or Manager can follow/unfollow without losing permissions. **Do not implement it as part of this plan.**

## 9. Final architecture decision

- **Global user roles:** existing Admin/Editor/Reviewer/etc. authorization system.
- **ProducerMembership:** N:N between User and Producer, with `membership_type` = owner/manager/contributor only.
- **Follow:** no implementation now; independent polymorphic relationship in a future project.

**Priority:** Finish and secure Producer memberships and UserDetail first; defer all social following features.
