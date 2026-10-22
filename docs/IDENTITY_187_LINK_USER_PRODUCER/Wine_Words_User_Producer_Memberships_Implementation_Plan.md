# Wine Words — User Detail, Producer Memberships and Self-Service Editing

**Status:** ✅ **Implemented**  (22 October 2026)  
**Date:** 22 October 2026  
**Repositories:**
- API: https://github.com/romalopes/wine_words_api
- Frontend: https://github.com/romalopes/wine_words_frontend

> **Implementation complete:** All phases documented below. The feature enables Admins to manage User→Producer links from `/users/:id`; linked users see and edit their Producers from `/account` with server-side authorization.

### Phase Documentation

| Phase | Document | Summary |
|-------|----------|---------|
| 0 | [`phases/phase-0-repository-audit.md`](phases/phase-0-repository-audit.md) | Verified codebase conventions: API uses `User` (not `Account`); `/users` is Admin-only; producer edits guarded by `wine_manager?` (Admin/Editor/Reviewer). |
| 1 | [`phases/phase-1-schema-and-models.md`](phases/phase-1-schema-and-models.md) | Migration `20261021234637_create_producer_memberships.rb`, `ProducerMembership` model, `User`/`Producer` associations. |
| 2 | [`phases/phase-2-api-and-authorization.md`](phases/phase-2-api-and-authorization.md) | Admin-only membership CRUD at `/api/v1/users/:user_id/producer_memberships`, user detail at `GET /api/v1/users/:id`, current user producers at `GET /api/v1/account/producers`; producer edit policy extended for linked users. |
| 3 | [`phases/phase-3-frontend-user-management.md`](phases/phase-3-frontend-user-management.md) | `/users` rows link to `/users/:id`; new `UserDetail` component with role/subscription controls + membership management; debounced producer selector. |
| 4 | [`phases/phase-4-account-producers.md`](phases/phase-4-account-producers.md) | "My Producers" card in `/account` linking to existing `/producers/:slug/edit`; reuses shared `ProducerForm`. |
| 5 | [`phases/phase-5-verification-and-rollout.md`](phases/phase-5-verification-and-rollout.md) | All RSpec request/model specs pass (12 membership specs, 6 user search specs, 10 account specs, 4 model specs); frontend build + TypeScript + 357/360 tests pass (3 pre-existing ApiHealth failures). |

## 1. Objective

Introduce a many-to-many association between application users/accounts and Producers. Admins and Editors will manage associations from a new user detail page. Associated users will see their Producers under `/account` and may edit Producer information without receiving global Editor/Admin privileges.

### Expected user journeys

1. Admin/Editor opens `/users`, searches or filters, and selects a user.
2. `/users/:id` shows identity, global roles, subscription, and linked Producers.
3. Admin/Editor changes allowed global roles or subscription through the existing backend workflows.
4. Admin/Editor searches Producers using a reusable selector and links/unlinks them.
5. The affected user visits `/account`, sees **My Producers**, and opens an existing Producer edit form.
6. Backend authorization permits edits only for global authorized roles or users with an active association.

### Explicit initial scope

- Many users per Producer and many Producers per user.
- Only Admin/Editor can link and unlink memberships.
- Linked users can edit Producer details but cannot grant access to others.
- Preserve the current subscription and global role semantics.
- No invitations, ownership verification, or producer-specific access tiers in v1.

### Out of scope for v1

- Producer-specific `owner/manager/contributor/viewer` roles.
- Producer onboarding, invitations, claims, and membership approval.
- Producer billing or membership-derived subscriptions.
- Automatic permissions over reviews, wines, analytics, or unrelated resources unless explicitly covered by existing rules.

## 2. Architecture and decisions

### 2.1 Domain model

```text
User (or Account) 1 --- N ProducerMembership N --- 1 Producer

User/Account
  id, email, ...

ProducerMembership
  id
  user_id (or account_id, consistent with real model)
  producer_id
  created_by_id (nullable, references actor)
  created_at, updated_at

Producer
  id, name, ...
```

Use `producer_memberships` instead of a bare HABTM table to retain association metadata and allow future growth. **Do not add a producer-specific `role` field in v1** unless inspection finds an established membership pattern requiring it.

Schema requirements:
- Foreign keys to the actual user/account and producer tables.
- Unique composite index `(user_id, producer_id)` (or equivalent account key).
- Index on `producer_id`; foreign-key indexes as appropriate.
- `created_by_id` should reference the actual actor type; decide deletion semantics deliberately (e.g., `nullify` when admin is deleted).
- Both primary association foreign keys `NOT NULL`.
- Preserve historical producer associations according to existing delete/soft-delete policy.
- Avoid duplicating existing association tables if one already fulfills the requirements.

Example migration skeleton (adapt to current schema):

```ruby
class CreateProducerMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :producer_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :producer, null: false, foreign_key: true
      t.references :created_by, null: true,
        foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_index :producer_memberships, [:user_id, :producer_id], unique: true
  end
end
```

**Note:** Match the application's migration version, real table names, and database FK conventions. If PostgreSQL migrations or model associations already exist, modify the plan rather than creating a parallel concept.

### 2.2 Rails associations

```ruby
# User (or Account)
has_many :producer_memberships, dependent: :destroy
has_many :producers, through: :producer_memberships

# Producer
has_many :producer_memberships, dependent: :destroy
has_many :users, through: :producer_memberships

# ProducerMembership
belongs_to :user
belongs_to :producer
belongs_to :created_by, class_name: 'User', optional: true
validates :user_id, uniqueness: { scope: :producer_id }
```

The unique database index is the final concurrency guard. Return a predictable conflict/validation response for duplicate links; do not rely only on model validation.

### 2.3 Permission matrix

| Operation | Admin | Editor | Linked regular user | Unlinked user |
|---|---|---|---|---|
| Open `/users` and `/users/:id` | Yes | Yes | No | No |
| View all membership associations | Yes | Yes | Own only | No |
| Add/remove Producer memberships | Yes | Yes | No | No |
| Assign/revoke Admin role | Yes, with self-protection | No | No | No |
| Edit non-Admin global roles | According to existing policy | According to existing policy | No | No |
| Change user subscription | According to existing policy | According to existing policy | No | No |
| Edit Producer | Yes | Yes | If linked | No |
| Change membership through `/account` | Yes, through admin flow | Yes, through admin flow | No | No |

**Security rules:** Global Admin/Editor authority must not be inferred from Producer membership. Editors must not escalate themselves or others to Admin. Retain any existing last-admin or self-revocation protections. Apply the same authorization to direct API requests, not just UI controls. A user cannot modify associations by sending an unauthorized `user_id` or `producer_id` in a Producer update payload.

### 2.4 API contracts (illustrative)

Prefer the existing namespace, response envelope, pagination, serializers and authentication mechanisms. Suggested REST shape:

```http
GET    /api/v1/users/:user_id/producer_memberships
POST   /api/v1/users/:user_id/producer_memberships
DELETE /api/v1/users/:user_id/producer_memberships/:id
GET    /api/v1/account/producers
GET    /api/v1/producers?query=...
GET    /api/v1/producers/:id
PATCH  /api/v1/producers/:id
```

Possible POST request:

```json
{ "producer_id": 123 }
```

Possible membership response:

```json
{
  "id": 456,
  "producer": { "id": 123, "name": "Example Estate" },
  "created_at": "2026-10-22T00:00:00Z"
}
```

- Membership management endpoints require global Admin/Editor authorization.
- `account/producers` is scoped to the authenticated user on the server; never accept a client-controlled account ID for this endpoint.
- Producer search must reuse existing pagination and permission semantics; do not expose private user data unnecessarily.
- Producer updates use the existing update endpoint and existing strong-parameter allowlist; only add the new authorization path.
- Define response codes: `401` unauthenticated, `403` unauthorized, `404` missing/inaccessible, `422` validation, `409` duplicate if consistent with existing API behavior.
- Ensure changes to user global roles and subscriptions use the existing endpoints; do not create parallel mutations.

## 3. Frontend UX

### 3.1 `/users` — simplified admin directory

Replace the dense inline editing controls inside `admin-user-card` with:
- User name (clickable link to `/users/:id`), email.
- Role badges, current subscription, linked Producer count if cheaply available.
- Search/filter/pagination preserved.
- Optional **View details** action.

Remove role checkboxes, subscription dropdown and Save Roles button **from the list card** once equivalent functionality is working in UserDetail. Keep navigation back to the list and preserve search/page query parameters where practical.

### 3.2 `/users/:id` — UserDetail

Recommended components:

```text
UserDetailPage
├── UserDetailHeader (name, email, status, back link)
├── UserGlobalRolesEditor (reuse current role logic)
├── UserSubscriptionEditor (reuse current subscription logic)
└── UserProducerMemberships
    ├── ProducerSearchSelect (reusable)
    └── ProducerMembershipList (unlink with confirmation)
```

Behavior:
- Initial loading, missing user, access denied, and save errors handled.
- Global roles and subscription can save independently if existing UI does so; avoid accidental overwrites from stale form state.
- Preserve existing self-Admin protection and role dependency rules.
- Producer search is keyboard accessible, debounced, and supports pagination/large result sets.
- Exclude or clearly mark already linked Producers.
- Link action shows pending/success/error; list updates without a full reload.
- Unlink requires confirmation and immediately revokes Producer editing authorization.
- A failure in one section should not corrupt unrelated sections.

### 3.3 Reusable `ProducerSearchSelect`

Before creating, search for existing Producer autocomplete, select, picker, and search hooks. Reuse where possible. Desired props (adapt to code conventions):

```ts
type ProducerSearchSelectProps = {
  selectedIds?: number[];
  excludedIds?: number[];
  onSelect: (producer: ProducerSummary) => void;
  disabled?: boolean;
  placeholder?: string;
};
```

Support query debouncing, request cancellation/stale-response protection, accessible listbox interaction, loading/empty/error states, and no duplicate selection.

### 3.4 `/account` — My Producers

Add a **My Producers** section to the existing account page:
- Fetch only authenticated user's linked Producers.
- Display Producer name, optional logo/region, and Edit action.
- Show useful empty state when no Producer is linked.
- Route Edit to the existing Producer editor rather than duplicating forms.
- Hide membership management actions from this page.
- Respect backend authorization when a link is removed during an open editing session.

### 3.5 Producer editor reuse

Use the same Producer form for admin/editor and associated user flows. Avoid UI duplication and avoid exposing administrative-only controls to associated users. On save, Rails independently validates permission. Do not assume a hidden button prevents an API request.

## 4. Phased implementation with AI coding prompts

Run these prompts **in order**. Each prompt assumes the coding assistant has the relevant repository checked out and can inspect files. Require focused commits/PRs and no unrelated refactoring.

### Phase 0 — Repository audit and design confirmation

**Goal:** Identify actual models, routes, authorization, components and tests before implementation.

**AI prompt — API**

```text
You are working in https://github.com/romalopes/wine_words_api.
Read the actual repository. Do not assume the model is named User rather than Account.
Inspect schema/migrations, Producer and user/account models, authentication,
RBAC/authorization, controllers, serializers, routes, subscriptions, existing
producer relationships, specs and factories.

Task: Plan an N:N user-to-producer association managed by Admin/Editor.
Linked users must be allowed to update associated Producers without global
Admin/Editor role. Find existing mechanisms to reuse.

Deliver:
1. Current architecture with exact file paths and key methods.
2. Any existing overlapping association and migration risks.
3. Proposed schema, endpoints, policies and serializer changes.
4. Existing role and subscription APIs to preserve.
5. Test plan and open decisions.
Do not modify code in this phase.
```

**AI prompt — Frontend**

```text
You are working in https://github.com/romalopes/wine_words_frontend.
Inspect /users, /account, routing, user cards, role editor, subscription
selector, Producer search/select components, Producer edit forms, API hooks,
state management and tests.

Design a /users/:id UserDetail page containing global role editor,
subscription editor and Producer association manager. Simplify /users to
summary/navigation. Add My Producers to /account with Edit links.

Deliver exact component/file reuse map, route guard approach, API contract
expectations, accessibility plan and tests. Do not modify code yet.
```

**Exit criteria:** Confirm naming and schema, authorization convention, reusable components, and exact API contract before code changes.

### Phase 1 — Database and models (API)

**AI prompt**

```text
Implement the approved user/account-to-Producer N:N association in the
Wine Words Rails API using a ProducerMembership join model.

Requirements:
- Follow actual schema/model names and migration conventions.
- Required foreign keys, unique composite index, appropriate indexes,
  creator metadata, and deletion semantics.
- ActiveRecord associations, validations and appropriate inverse relations.
- Do not introduce producer-specific roles in v1.
- Do not create a duplicate table if equivalent functionality exists.
- Add model tests for N:N relationships, duplicates, foreign keys and deletion.
- No changes to global role or subscription semantics.

Run available migrations and tests. Report modified files, commands,
results and any deviations from the plan.
```

**Exit criteria:** Migration reversible, associations tested, duplicate rows impossible even under concurrency.

### Phase 2 — API authorization and membership endpoints

**AI prompt**

```text
Implement Producer membership management endpoints in the Wine Words API.
Use existing authentication, authorization, versioning, serializers and
controller patterns.

Admin and Editor can list, add and remove memberships for any user.
Ordinary users cannot mutate memberships. Provide an authenticated
current-account Producers endpoint scoped server-side to current user.

Update Producer edit authorization so global Admin/Editor OR a linked user
may edit permitted Producer fields. Do not grant permissions over roles,
subscriptions, membership lists, or unrelated resources. Ensure an Editor
cannot grant Admin role through existing user update APIs.

Implement consistent validation/errors, safe parameter handling, duplicate
association handling and pagination if necessary. Add request/policy tests
for authorized and unauthorized access, IDOR attempts, duplicate links,
removed membership, and direct API calls. Document actual endpoints.
```

**Exit criteria:** All permission cases pass API tests; unlink revokes access immediately; no privilege escalation.

### Phase 3 — Refactor `/users` and implement UserDetail

**AI prompt**

```text
In Wine Words React/Vite frontend, refactor /users to a lightweight user
summary list. Each name links to /users/:id. Preserve search, pagination,
role badges, subscription summary and existing styling.

Create UserDetail with header, global role editor and subscription editor.
Move/reuse the existing role checkboxes, Save Roles behavior, subscription
selector, disabled self-Admin control, API hooks and error handling.
Do not reimplement business rules in a different way. Enforce Admin/Editor
route access and preserve backend restrictions.

Include loading/empty/error states, responsive layout, keyboard support,
and tests for navigation and role/subscription editing. No Producer UI yet.
Report changed files and test results.
```

**Exit criteria:** `/users` no longer edits inline; `/users/:id` preserves prior administrative functionality and guardrails.

### Phase 4 — Producer selector and memberships in UserDetail

**AI prompt**

```text
Inspect the Wine Words frontend for existing Producer search/select
components and hooks. Reuse or extract a shared ProducerSearchSelect rather
than creating duplicate search implementations.

Add Associated Producers to UserDetail:
- list linked Producers and count;
- search Producers by name using existing search API;
- link selected Producer;
- prevent duplicate associations;
- unlink with confirmation;
- show loading, success, empty and error states;
- refresh/update the membership list after mutation;
- handle rapid typing and stale network responses.

Only Admin/Editor can see the management UI. Backend remains authoritative.
Add component and integration tests with mocked API success, conflict,
403, network failure and unlink cases. Follow existing UI conventions.
```

**Exit criteria:** Admin/Editor can manage N:N links without duplicates; clear feedback and accessible interaction.

### Phase 5 — `/account` My Producers and editing

**AI prompt**

```text
Add My Producers to the existing Wine Words /account page.
Fetch linked Producers through the authenticated account-scoped endpoint.
Display Producer name and useful summary with an Edit action. Show a helpful
empty state for users with no associations.

Reuse the existing Producer edit route/form, including validation and
image/logo handling. A linked ordinary user must be able to edit allowed
Producer fields, but must not see or invoke membership/global-admin actions.
Keep existing Admin/Editor edit behavior unchanged.

Add tests for zero/one/many Producers, edit navigation, permitted edits,
forbidden unlinked Producer access, and a membership removed mid-session.
```

**Exit criteria:** Linked regular user can edit their Producer; unrelated Producer is inaccessible; one shared editor is used.

### Phase 6 — Security, quality and end-to-end verification

**AI prompt — API and frontend (run in each repository)**

```text
Perform a focused security and regression review of Wine Words Producer
memberships and UserDetail. Verify:
- Admin/Editor membership management;
- Editor cannot assign/revoke Admin privileges;
- self/last-Admin protections remain intact;
- ordinary users cannot open admin user endpoints;
- linked users can edit only linked Producers;
- unlink revokes authorization immediately;
- account-scoped query cannot be redirected to another user;
- mass assignment cannot change memberships/roles through Producer PATCH;
- duplicate requests cannot create duplicate links;
- no regression to existing roles, subscriptions, Producer edit and search;
- API response shapes match frontend types;
- loading, empty, validation and failure UX;
- responsive and accessible navigation.

Run repository lint/typecheck/unit/request/E2E suites where available.
Fix issues found without unrelated refactors. Return a checklist with
commands, test results and any untested risks.
```

**Exit criteria:** Permission matrix covered; existing functionality regression-tested; CI green.

### Phase 7 — Deployment and rollout

**AI prompt — release checklist**

```text
Prepare a production rollout checklist for the implemented Wine Words
Producer memberships feature. Inspect actual CI/CD and hosting settings.

Include:
- migration order and compatibility with existing app version;
- backup/rollback strategy for PostgreSQL;
- deploy API before frontend where API contract requires it;
- smoke tests for /users, /users/:id, /account, Producer edit;
- verification for Admin, Editor, linked and unlinked users;
- monitoring of 403/422/409 responses and unexpected exceptions;
- rollback behavior and handling of already-created membership rows.

Do not deploy automatically. Output exact commands only after confirming
real project scripts and environment configuration.
```

**Exit criteria:** Staging verification complete; production migration and smoke tests completed; no authorization regression.

## 5. Manual verification checklist

- [ ] Admin can open users list and detail.
- [ ] Editor can open users list and detail.
- [ ] Ordinary user cannot access users list/detail (including direct API).
- [ ] User cards show accurate global roles and subscription.
- [ ] Role editing works in UserDetail without changing existing safeguards.
- [ ] Editor cannot grant Admin role.
- [ ] Existing subscription changes still work.
- [ ] Producer search returns expected results and handles empty queries.
- [ ] Admin/Editor can link several Producers to one user.
- [ ] Admin/Editor can link several users to one Producer.
- [ ] Duplicate link attempt is rejected cleanly.
- [ ] Admin/Editor can unlink an association.
- [ ] `/account` shows only current user's Producers.
- [ ] Linked ordinary user can edit an associated Producer.
- [ ] Unlinked ordinary user cannot edit that Producer, including via API.
- [ ] User loses editing access immediately after unlink.
- [ ] Linked user cannot add/remove memberships or edit global roles.
- [ ] Producer edit form is shared with existing admin/editor flow.
- [ ] Existing Producer images, fields and validations still work.
- [ ] Mobile layout, keyboard navigation and loading/error states verified.
- [ ] Database migration, automated tests and CI pass.

## 6. Recommended work breakdown

| Work item | Repository | Dependencies |
|---|---|---|
| Audit architecture | API + frontend | None |
| Membership migration/models | API | Audit |
| Membership endpoints and policies | API | Models |
| Simplified `/users` + UserDetail | Frontend | Audit, existing APIs |
| Shared Producer selector + memberships UI | Frontend | Membership API |
| `/account` My Producers | Frontend | Account Producers API |
| Producer edit authorization | API | Models |
| End-to-end security/regression tests | Both | All above |
| Rollout | Both | Tests and staging |

Suggested PRs: **(1)** API schema, **(2)** API authorization/endpoints, **(3)** frontend UserDetail refactor, **(4)** frontend membership management, **(5)** account Producer editing, **(6)** hardening/tests. Coordinate API authorization before enabling account edit links.

## 7. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Editor gains Admin privileges | Explicit policy for global role mutation; request tests |
| User edits unrelated Producer | Backend association-based policy and direct API tests |
| Duplicated Producer editing form | Reuse existing form and validation |
| Duplicated membership records | Unique DB index + model validation + conflict handling |
| Unexpected user/account model mismatch | Phase 0 code audit before migration |
| Inconsistent role/subscription behavior | Move existing components, don't replace business logic |
| Large Producer catalog makes search slow | Server-side search/pagination and debounced UI |
| Unlink while editor open | Recheck authorization on every save |
| Sensitive user data exposed | Scope account endpoints; admin-only membership endpoints |
| Production migration issues | Backup, backward-compatible migration and staged rollout |

## 8. Future enhancements (not part of v1)

- Producer membership roles (`owner`, `manager`, `contributor`, `viewer`).
- Invitations and verified ownership claims.
- Producer-level permission policies for wine catalogs, analytics and publication workflows.
- Producer member management by verified owners.
- Audit log with actor, before/after and reason for association changes.
- Producer dashboard with analytics, editorial queue and subscription status.

## 9. Definition of done

The feature is complete when Admins/Editors can navigate from `/users` to `/users/:id`, manage existing roles/subscriptions and N:N Producer links, and an ordinary associated user can discover and edit their Producers from `/account`, with all permissions enforced server-side, regression tests passing, and the existing Producer edit component reused.
