# Wine Words — User Detail, Producer Membership Types & Following

**Status:** Implementation plan v2 — 22 October 2026  
**API:** https://github.com/romalopes/wine_words_api  
**Frontend:** https://github.com/romalopes/wine_words_frontend  
**Local pages:** `/users`, `/users/:id`, `/account`, `/producers/:slug`

> This is a design plan, not a verified audit of current repositories. Before editing, inspect the actual Rails models, migrations, route names, authentication/authorization, user-role implementation, Producer slug resolution, React routes and shared components. Preserve existing conventions. In particular, do not assume that `/producers/unknown-producer` is a valid Producer: treat it as an example route and handle not-found cases correctly.

## 1. Goals and user stories

1. Admin/Editor opens `/users`, selects a user, and opens `/users/:id`.
2. `UserDetail` manages **global user roles**, subscription and **Producer memberships** in separate sections.
3. Admin/Editor searches existing Producers, links one to the selected user and chooses `membership_type` (`owner`, `manager`, `contributor`, `follower`). They can update or remove a link.
4. Any authenticated user viewing a real Producer detail page can click **Follow**; the API creates a link to the *current authenticated user* with `membership_type = follower`.
5. A user can **Unfollow** if their current membership is `follower`; following must never downgrade or delete an `owner`, `manager`, or `contributor` membership.
6. `/account` shows **Managed Producers** (`owner`, `manager`, `contributor`, with permission-specific actions) and **Following** (`follower`). Users can edit Producers only if permitted by membership type or global authorization.
7. Existing Admin/Editor permissions and global role assignment remain distinct from Producer membership types.

## 2. Domain design

### 2.1 Membership types

| `membership_type` | Meaning | Producer editing | Membership administration |
| --- | --- | --- | --- |
| `owner` | Responsible representative of Producer in Wine Words, not verified legal ownership | Yes | Admin/Editor only in v1 |
| `manager` | Manages Producer information | Yes | No |
| `contributor` | Contributes Producer-related content when that feature is authorized | No general Producer edit by default | No |
| `follower` | Interested user following Producer updates | No | Can unfollow self |

**Global roles** (Admin, Editor, Reviewer, Reader, etc.) are not membership types. Do not rename or modify the existing global `role`/`roles` fields. Only the ProducerMembership attribute is named `membership_type`.

### 2.2 Single-membership constraint and implications

Use one ProducerMembership per `(user_id, producer_id)`, with a unique composite index. A person cannot simultaneously hold `manager` and `follower` records for the same Producer. In v1, a privileged membership implies an association but does **not** automatically subscribe to follower-only notifications. If independent following/notification preferences are later required, introduce a separate follow preference/relationship; do not overload the membership type silently.

### 2.3 Migration — new installation

Use the Rails migration version matching the repository (the example below uses Rails 8.1). If the existing `CreateProducerMemberships` migration has **not** run in any shared database, update it. If it has run, create a **new additive migration** instead of rewriting migration history.

```ruby
class CreateProducerMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :producer_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :producer, null: false, foreign_key: true
      t.string :membership_type, null: false, default: "follower"
      t.references :created_by, null: true,
                   foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end

    add_index :producer_memberships, [:user_id, :producer_id], unique: true
    add_check_constraint :producer_memberships,
      "membership_type IN ('owner', 'manager', 'contributor', 'follower')",
      name: "producer_memberships_type_check"
  end
end
```

**Migration for existing databases:** inspect the schema first. If a `role` column exists, rename it to `membership_type` in a new migration; convert `viewer` values to `follower` and update defaults/check constraints/enum mappings safely. If `membership_type` does not yet exist, add and backfill it instead. If an existing membership has no type, determine a safe backfill based on how it was created: do not automatically downgrade previously granted edit access to `follower`. Include rollback strategy and data verification SQL.

### 2.4 Rails models

```ruby
class ProducerMembership < ApplicationRecord
  belongs_to :user
  belongs_to :producer
  belongs_to :created_by, class_name: "User", optional: true

  enum :membership_type, {
    owner: "owner",
    manager: "manager",
    contributor: "contributor",
    follower: "follower"
  }

  validates :user_id, uniqueness: { scope: :producer_id }
end
```

In `User` (or the real identity model): `has_many :producer_memberships` and `has_many :producers, through: :producer_memberships`. In `Producer`: `has_many :producer_memberships` and `has_many :users, through: :producer_memberships`. Reuse any existing relationships; define appropriate dependent behavior and ensure audit fields remain valid.

## 3. Authorization and security

| Operation | Admin | Editor | Owner | Manager | Contributor | Follower |
| --- | --- | --- | --- | --- | --- | --- |
| View `/users/:id` | Yes | Yes | No | No | No | No |
| Assign Producer membership type | Yes | Yes (except restricted owner assignment, if policy requires) | No | No | No | No |
| Link/unlink other users | Yes | Yes | No | No | No | No |
| Edit Producer details | Yes | Yes | Yes | Yes | No by default | No |
| Follow self | Yes | Yes | Yes* | Yes* | Yes* | Yes* |
| Unfollow self | Only if follower | Only if follower | No membership deletion | No membership deletion | No membership deletion | Yes |

`*` If an operational membership already exists, the Follow action must be a no-op or show `Associated`, never convert that membership to follower. Public Producer pages remain visible per existing visibility rules.

- Server must derive the follower `user_id` from the authenticated session/token, not request JSON.
- Only authorized Admins/Editors may set arbitrary `membership_type` and manage another user's membership.
- Do not allow self-service follow/unfollow to alter or delete operational memberships.
- Avoid IDOR: authorize every user and Producer ID, including read endpoints and edit actions.
- Protect global Admin role assignment separately (e.g., Editors cannot promote themselves to Admin).
- Decide whether Owner assignment/removal needs additional safeguards and whether a Producer must retain at least one Owner. Enforce any invariant transactionally.
- Handle duplicate requests/races with the unique DB index and predictable idempotent API behavior.
- Record `created_by_id` for administrative links; for self-follow, either record the follower as actor or use a documented audit convention.
- Follow/unfollow should not trigger emails or notifications in v1 unless separately approved.

## 4. API design (adapt routes to existing namespace)

### 4.1 Administrative membership endpoints

```http
GET    /api/v1/users/:user_id/producer_memberships
POST   /api/v1/users/:user_id/producer_memberships
PATCH  /api/v1/users/:user_id/producer_memberships/:id
DELETE /api/v1/users/:user_id/producer_memberships/:id
```

Example admin create/update payload:

```json
{
  "producer_membership": {
    "producer_id": 45,
    "membership_type": "manager"
  }
}
```

Example response:

```json
{
  "id": 123,
  "user_id": 12,
  "producer_id": 45,
  "membership_type": "manager",
  "producer": { "id": 45, "name": "Example Producer", "slug": "example-producer" }
}
```

Use existing serializers, pagination and error conventions. Admin update should change `membership_type` without deleting/recreating the membership. Return validation errors for unsupported types and conflicts for duplicates.

### 4.2 Authenticated self-service follow endpoints

```http
POST   /api/v1/producers/:producer_id/follow
DELETE /api/v1/producers/:producer_id/follow
GET    /api/v1/account/producers
```

**POST behavior:**
1. Require authentication; resolve the real Producer from ID or slug consistently with current routing.
2. If no membership exists, create `membership_type: "follower"` for `current_user`.
3. If `follower` exists, return success with no duplicate.
4. If `owner`/`manager`/`contributor` exists, return success with existing association unchanged and a status the UI can display as `Associated`.
5. Never accept `user_id` or `membership_type` from the follow request.

**DELETE behavior:**
1. Require authentication and find the current user's membership.
2. Delete only when `membership_type == "follower"`.
3. If absent, return idempotent success; if operational membership exists, preserve it and return an explicit non-destructive response (e.g., 409 Conflict).

**GET account producers:** return Producer summaries plus `membership_type` and derived allowed actions. Prefer a producer detail endpoint to include `current_user_membership_type`, `is_following`, and `can_edit` without exposing other members or private account data.

## 5. Frontend UX

### 5.1 `/users` — admin directory

Keep a clean list of users with name, email, global roles, subscription, Producer membership count, and `View/Edit` link. Move the existing role checkboxes and subscription editor into UserDetail rather than duplicating controls on every list card.

### 5.2 `/users/:id` — UserDetail

Restricted to Admin/Editor. Sections:
- **User information:** name, email, status, basic account metadata.
- **Global roles:** existing checkboxes and save workflow; retain Admin self-protection and authorization rules.
- **Subscription:** existing subscription selector and save workflow.
- **Producer memberships:** searchable Producer picker (reuse existing component if available), membership type selector (`Owner`, `Manager`, `Contributor`, `Follower`), Add/Save/Remove actions, and current memberships table.

For each linked Producer show name, slug/link, `membership_type`, assigned date and permitted controls. When a Producer is selected but not linked, allow Add with an explicit membership type. For an existing membership, change the type with PATCH; do not create a duplicate. Require confirmation for removal and for sensitive Owner changes as appropriate.

**Acceptance criteria:** Admin/Editor can open `/users/:id`, search Producers, add one with `membership_type`, edit that type, and unlink it. Errors, loading, empty results and duplicate links are handled. Non-Admin/Editor cannot access the page or API.

### 5.3 Reusable ProducerSearchSelect

Search Producers by name (and region/slug if supported), debounce queries, paginate, support keyboard accessibility, avoid duplicate choices, and display a clear selected state. Inspect and reuse an existing Producer picker before creating a new one. Component should be reusable in both UserDetail and future Producer management screens.

### 5.4 `/producers/:slug` — Follow / Unfollow

The supplied local URL `/producers/unknown-producer` is an example of the route shape, not necessarily a real record.

- For a valid Producer and an unauthenticated visitor: show `Follow` leading to sign-in, then return to the Producer page.
- Authenticated user with no membership: show **Follow**; clicking calls POST follow and updates the UI to **Following**.
- Authenticated `follower`: show **Following** / **Unfollow**; clicking Unfollow calls DELETE and returns to **Follow**.
- Authenticated `owner`/`manager`/`contributor`: show **Associated — Owner/Manager/Contributor** (and optionally `Edit Producer` where authorized); do not display an action that downgrades their membership.
- Show pending states, accessible labels and API error messages; disable duplicate submissions.
- Unknown Producer slug: show not-found page and no follow action; never create a Producer implicitly.

### 5.5 `/account` — Managed Producers and Following

- **Managed Producers:** `owner`, `manager`, `contributor` with clear membership labels; `Edit Producer` only for owner/manager or separately authorized roles.
- **Following:** `follower` memberships with Producer detail link and Unfollow action.
- Reuse existing Producer edit form and existing account layout; do not create a second editor.
- If the user has no associations, show an empty state linking to Producer discovery.

## 6. Phased implementation and AI coding prompts

### Phase 0 — Audit existing code and confirm design

**Tasks:** inspect `db/schema.rb`, Producer/User models, RBAC/policies, migrations, controller namespaces, `/users` and `/account` routes, Producer detail component, search selectors, tests, existing membership work and deployment environments. Identify whether original migration ran and whether `role` or `viewer` data already exists. Report findings and proposed file changes before coding.

**AI prompt — Audit**

> Audit `romalopes/wine_words_api` and `romalopes/wine_words_frontend` for the ProducerMembership feature. Find actual User/Account, Producer, global role and subscription models; existing memberships; migrations and data; authorization policies; API routing; `/users`, `/users/:id`, `/account`, and `/producers/:slug`; Producer search components; and tests. The desired ProducerMembership attribute is `membership_type`, with owner/manager/contributor/follower. Do not confuse it with global user roles. Identify all existing code that needs adapting, whether migrations have run, and any risks. Produce a file-by-file implementation plan before changing code.

**Exit criteria:** reviewed model/route mapping and migration strategy.

### Phase 1 — Database migration and model

**Tasks:** implement `membership_type` string enum with `follower` default, constraints, indexes, associations, audit actor, validations; migrate existing `role` safely if necessary; convert `viewer` values if present; preserve existing editing privileges during backfill; add model tests.

**AI prompt — Backend model**

> Implement ProducerMembership in the Rails API using `membership_type` (not `role`), with string enum owner/manager/contributor/follower, follower default, DB check constraint, unique `(user_id, producer_id)` index, `created_by` audit association and User/Producer relationships. Inspect current migration state. If existing migrations ran, write a new safe migration and backfill; do not edit applied history. If `role`/`viewer` already exists, migrate carefully to `membership_type`/`follower`, preserving operational permissions. Add model tests for enum values, defaults, uniqueness and FK behavior. Run migration and tests; report commands and results.

**Exit criteria:** schema valid, existing records preserved, tests pass.

### Phase 2 — Administrative membership API and authorization

**Tasks:** implement membership list/create/update/delete for Admin/Editor; ensure only allowed membership types, proper user and Producer lookup, audit changes, pagination/serialization and error responses. Enforce permission separation from global roles and Producer edit policies.

**AI prompt — Admin API**

> In the Wine Words Rails API, implement secure Admin/Editor ProducerMembership CRUD for a selected user, using `membership_type` exclusively. Follow current routes, policies, controllers and serializers. Allow Admin/Editor to assign owner/manager/contributor/follower, change membership_type with PATCH and unlink with DELETE. Enforce authorization on every action; avoid duplicate memberships and race conditions; protect global Admin roles independently. Ensure Producer editing is allowed for owner/manager (plus existing global authorized roles), not follower; contributor receives only separately defined content permissions. Add request/policy tests for all types and unauthorized access.

**Exit criteria:** admin API works and permissions are tested.

### Phase 3 — Refactor `/users` and create `/users/:id`

**Tasks:** simplify user list; add detail link; build UserDetail with global roles, subscription and Producer memberships sections; preserve existing global role/subscription behavior; provide routing, loading, error and navigation states.

**AI prompt — UserDetail**

> In `wine_words_frontend`, inspect the current `/users` admin-user-card UI and global role/subscription APIs. Refactor the list to show summary fields and a link to `/users/:id`. Build an Admin/Editor-only UserDetail page with user info, existing global role controls, subscription selector and a Producer memberships section. Do not rename the global role fields. Use existing React router, design system, API client and tests. Preserve protections around Admin role assignment and existing subscription behavior. Add navigation and access-control tests.

**Exit criteria:** `/users/:id` works and existing role/subscription flows remain intact.

### Phase 4 — Producer search and membership type editing in UserDetail

**Tasks:** reuse/build ProducerSearchSelect; add association with type; list current associations; edit `membership_type`; unlink with confirmation; handle duplicate, unauthorized, loading and empty states.

**AI prompt — UserDetail memberships**

> Implement the Producer memberships panel on `/users/:id`. Reuse an existing searchable Producer selector if present; otherwise build an accessible reusable ProducerSearchSelect. Admins/Editors must be able to search Producers, select a Producer, choose `membership_type` from Owner/Manager/Contributor/Follower, create the link, update membership_type for an existing link, and unlink it. Use the backend administrative endpoints and current API client conventions. Display current memberships with their membership_type. Do not allow duplicates or confuse this with global user roles. Add UI tests for create/update/delete, API errors and permission gates.

**Exit criteria:** all four membership types can be managed by authorized administrators.

### Phase 5 — Producer detail Follow/Unfollow

**Tasks:** add current-user membership state to Producer details, self-service follow endpoints and UI; ensure no membership escalation/downgrade; handle missing Producer slug and unauthenticated users.

**AI prompt — Follow backend**

> Implement self-service Follow/Unfollow for a real Producer in the Rails API. POST `/producers/:id/follow` creates a ProducerMembership for current_user with `membership_type: 'follower'` only when none exists. Repeated POST is idempotent. If current_user is already owner/manager/contributor, do not change the membership. DELETE removes only a follower membership; it must never delete owner/manager/contributor. Do not accept user_id or membership_type from client input. Use existing authentication and API conventions, add concurrency-safe behavior and comprehensive request tests, including nonexistent Producer, anonymous access and repeat calls.

**AI prompt — Follow frontend**

> On the existing Wine Words Producer detail page (`/producers/:slug`, e.g. `/producers/unknown-producer`), add a Follow control for authenticated users. When clicked for a real Producer, call the follow API to create a membership_type=follower. Show Following and Unfollow for follower memberships. Show Associated with the current membership_type for owner/manager/contributor without allowing the follow button to downgrade them. For anonymous visitors, direct to sign-in and preserve return URL. Handle loading, errors, missing Producers and accessibility. Reuse existing API and authentication patterns. Add component and integration tests.

**Exit criteria:** user can follow/unfollow a real Producer without changing privileged memberships.

### Phase 6 — `/account` Producer associations and editing

**Tasks:** show Managed Producers and Following; show type badges; link to existing Producer editor only for authorized users; enforce Rails authorization and test direct API access.

**AI prompt — Account and edit permissions**

> Extend `/account` with Managed Producers (owner/manager/contributor) and Following (follower), based on membership_type. Reuse the existing Producer edit page and components. Permit Producer detail edits for owner and manager plus existing globally authorized roles; do not grant edit to followers or contributors by default. Add Follow/Unfollow affordances only for followers. Update Rails authorization policies and tests so direct API requests cannot bypass frontend restrictions. Add account page UI tests for all membership types.

**Exit criteria:** account accurately reflects membership types and edit permissions.

### Phase 7 — Cross-cutting QA, security and migration verification

**Tasks:** run Rails tests, frontend unit/integration tests, lint, typecheck and build; verify DB migration/backfill and rollback; inspect N+1 queries and search pagination; test authorization/IDOR, CSRF/CORS according to auth architecture, duplicate clicks, concurrent follows and slug errors; confirm global RBAC unaffected.

**AI prompt — QA**

> Review the full ProducerMembership implementation across both Wine Words repos for security, regressions and consistency. Verify `membership_type` is used only for ProducerMembership, global roles remain untouched, all API actions enforce permissions, and self-follow cannot assign owner/manager/contributor. Test duplicate and concurrent follows, idempotent unfollow, unauthorized users, non-existent Producers, last-owner policy if implemented, account editing rules and migration backfill. Run existing test/lint/build commands and provide a concise report with failing tests and recommended fixes. Do not silently weaken security checks.

**Exit criteria:** no critical failures and permission matrix verified.

### Phase 8 — Deployment and release

**Tasks:** backup DB; review migration against production data; deploy backward-compatible schema first if code already uses `role`; deploy backend then frontend; smoke-test admin association creation, type update, Producer Follow, account listing and Producer editing; monitor Rails logs/Sentry; define rollback path that preserves membership records.

**AI prompt — Release checklist**

> Prepare a deployment checklist for the Wine Words ProducerMembership membership_type release on the actual hosting stack. Inspect migration status and whether an old `role` field is in production. Plan safe schema/code rollout and backfill with database backup and rollback. Include commands for Rails migration, backend and frontend test/build, manual smoke tests for `/users/:id`, `/producers/:slug`, `/account`, and monitoring for 4xx/5xx errors. Do not deploy automatically without approval.

**Exit criteria:** release verified in production and rollback documented.

## 7. Manual acceptance checklist

- [ ] Existing global user roles still use their original field/model and permissions.
- [ ] `ProducerMembership.membership_type` accepts only owner/manager/contributor/follower.
- [ ] Database default is follower; invalid values and duplicate user-Producer links are rejected.
- [ ] Existing membership data is migrated safely, with no accidental permission loss.
- [ ] `/users` links to `/users/:id`.
- [ ] Admin/Editor can search for Producers and assign any permitted membership_type on `/users/:id`.
- [ ] Admin/Editor can update membership_type without deleting/recreating the link.
- [ ] Unauthorized users cannot manage memberships or global roles.
- [ ] A valid `/producers/:slug` displays Follow for signed-in users without membership.
- [ ] Follow creates exactly one membership with `membership_type = follower` for current_user.
- [ ] Repeated Follow does not create duplicates.
- [ ] Unfollow deletes only follower membership.
- [ ] Following does not change owner/manager/contributor memberships.
- [ ] Anonymous Follow requires sign-in.
- [ ] Unknown Producer slug returns a proper not-found state; no membership is created.
- [ ] `/account` shows Managed Producers separately from Following.
- [ ] Owner/Manager can edit permitted Producer details; Contributor/Follower cannot edit by default.
- [ ] Direct API requests cannot bypass UI restrictions.
- [ ] Rails and React tests, lint/typecheck/build pass.

## 8. Risks, decisions and future enhancements

**Decision A — Single type per association.** One `membership_type` per user-Producer pair. Operational members are not automatically opted into notifications. If independent following becomes important, separate notification-follow state from operational membership rather than inventing multiple conflicting roles.

**Decision B — Ownership is not verified legal ownership.** An Admin/Editor assignment establishes application access. Later add Producer claims, verification and owner invitations if needed.

**Decision C — Contributor scope.** Contributor does not edit general Producer profile by default. Define future article/wine/review content permissions separately from Producer administration.

**Decision D — Follower notifications.** Follow records interest; no email or push notification system is included in this release. Future work may add opt-in alerts, digest preferences, activity feeds and follower counts.

**Decision E — Auditability.** Consider an immutable membership change log (`actor`, old type, new type, timestamp), beyond the initial `created_by_id`, for sensitive owner/manager transitions.

**Definition of done:** Admins/Editors can manage Producer `membership_type` from UserDetail; authenticated users can follow/unfollow Producers safely from Producer detail; `/account` shows correct associations; owner/manager Producer editing is authorized server-side; all changes are tested and deployable without changing global user roles.
