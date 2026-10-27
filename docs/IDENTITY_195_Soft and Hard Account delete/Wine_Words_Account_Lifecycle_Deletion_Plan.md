# Wine Words — Account Lifecycle & Safe Deletion Implementation Plan

**Project:** Wine Words (Rails API + React/Vite frontend)  
**Date:** 2026-10-26  
**Status:** Proposed; validate model names and existing behaviour against current repositories before implementation.

## 1. Objective

Implement a safe, auditable account lifecycle with **Deactivate**, **Soft Delete**, and **Hard Delete** actions. Administrators may hard-delete accounts that have **no blocking dependencies**. Disposable dependencies (likes, follows, notifications, sessions, tokens, preferences) do not by themselves prevent hard deletion and are cleaned up safely. Protect published content, producer responsibilities, active billing obligations, financial records, and legally required records.

**Repositories:**
- API: https://github.com/romalopes/wine_words_api
- Frontend: https://github.com/romalopes/wine_words_frontend

> This plan is a design proposal, not a claim that the repositories have been inspected. Verify real associations, migrations, auth mechanisms, controllers, permissions, and routes before coding.

## 2. Policy and decisions

| Situation | Admin action | Notes |
|---|---|---|
| No activity or only disposable records | Hard delete allowed | Clean dependents in one transaction |
| Draft review/article | Block hard delete initially | Optionally add explicit draft cleanup later |
| Published review/article | Block hard delete | Soft-delete account; preserve authored content subject to privacy policy |
| Comments | Block initially | Future moderation/anonymisation policy can permit deletion |
| Producer membership or ownership | Block | Reassign or revoke explicitly first |
| Active subscription | Block | Resolve billing/cancellation first |
| Financial records or retention obligations | Block direct hard delete | Separate retention and personal-data minimisation |
| Security investigation/legal hold | Block | Retention decision must be explicit |
| Last active administrator | Block deactivation/deletion | Avoid administrative lockout |

**Critical distinctions:**
- *Deactivation*: reversible access restriction, no `deleted_at`.
- *Soft deletion*: account no longer active or ordinarily visible; `deleted_at` set; historical associations retained.
- *Anonymisation*: distinct operation with separate `anonymized_at` and data-retention rules; not synonymous with soft deletion.
- *Hard deletion*: physical removal of user/account and disposable dependents, irreversible.

Never assume `dependent: :destroy` is harmless. Explicitly classify **every** association before enabling deletion. Decide whether the principal model is `User`, `Account`, or both; do not duplicate lifecycle state across models without a defined source of truth.

## 3. Discovery and inventory (Phase 0)

1. Inspect API models, schema, migrations, foreign keys, callbacks, Active Storage, authentication, OAuth identities, sessions, tokens, audit records, jobs, billing and all `User`/`Account` references.
2. Inspect roles/permissions and admin user management endpoints and frontend pages.
3. Generate a dependency inventory: association name, model/table, FK, `dependent:` option, retention requirement, deletion classification, and required cleanup.
4. Determine whether users have reviews, articles, comments, producer memberships, follows, likes, notifications, subscriptions, transactions, invites, analytics events, media, or background jobs.
5. Identify any data that may be retained outside PostgreSQL (R2/Active Storage, email provider, analytics, logs, backups, payment provider).
6. Document current account deletion behaviour, unique email constraints, and existing user-facing account settings.

**Deliverable:** `docs/account_lifecycle/dependency_inventory.md`, with actual model names and final policy table. **Gate:** No deletion code before this inventory is approved.

### AI prompt — Phase 0 (API)

```text
You are working in the Wine Words Rails API repository. Inspect the actual code; do not assume association names. Inventory every reference to User/Account including ActiveRecord associations, foreign keys, dependent callbacks, authentication, OAuth, sessions, subscriptions, payments, comments, reviews, articles, producer memberships, likes, follows, notifications, Active Storage, audit logs, background jobs, analytics and external services. Produce docs/account_lifecycle/dependency_inventory.md with: model/table, FK, deletion impact, classification (BLOCKING / DISPOSABLE / RETAIN-SEPARATELY / REVIEW), rationale, existing callbacks and recommended cleanup. Identify the actual account principal and the last-admin protection mechanism. Do not modify application behaviour yet.
```

### AI prompt — Phase 0 (frontend)

```text
Inspect the Wine Words React/Vite frontend for user management, account settings, roles/permissions, API clients and current delete/deactivate actions. Produce a concise route/component/API inventory and suggest where account lifecycle actions and blocking reasons belong. Do not implement yet. Use existing patterns and styling.
```

## 4. Data model and migration (Phase 1)

Prefer the smallest migration consistent with the existing schema:

- `deleted_at: datetime, null: true` with index on the authoritative account model.
- `status` enum/string **only if** there is not already an equivalent state mechanism; suggested `active`, `suspended`, `deactivated`, `deleted`.
- `anonymized_at` **only when** anonymisation is actually implemented; avoid speculative fields.
- Use explicit query scopes, e.g. `active_for_authentication`, `not_deleted`; **avoid `default_scope`**.
- Preserve historical references to soft-deleted authors; frontend may show “Deleted User”.
- Review uniqueness of emails, OAuth identities, usernames, and re-registration after soft deletion. Do **not** silently rewrite emails or free identifiers without privacy and account-recovery policy.
- Ensure all foreign keys and deletion behaviour are documented; use DB constraints for integrity.

Example (adapt to actual model):

```ruby
add_column :users, :deleted_at, :datetime
add_index :users, :deleted_at
```

State invariants: deleted users cannot authenticate or refresh tokens; existing sessions are revoked; suspended/deactivated users cannot log in; restoration must not bypass account verification. API access must not rely on frontend visibility.

### AI prompt — Phase 1

```text
Implement minimal account lifecycle persistence in the Rails API using the actual authoritative principal identified in dependency_inventory.md. Reuse existing status fields where possible; add deleted_at/index and migration only as needed. Avoid default_scope. Add explicit scopes and validation/invariants, and keep historical authorship readable. Update authentication to reject inactive/deleted users and revoke active sessions/tokens on lifecycle transitions. Handle email uniqueness and re-registration intentionally; document the choice. Add model/authentication tests. Do not implement hard deletion yet.
```

## 5. Deletion policy and dependency report (Phase 2)

Create a policy object, e.g. `Accounts::DeletionPolicy` (or `Users::DeletionPolicy`, matching the codebase), returning a **structured** report:

```json
{
  "hard_delete_allowed": false,
  "blocking_reasons": [
    {"code": "published_reviews", "count": 12, "message": "12 reviews"},
    {"code": "producer_memberships", "count": 1, "message": "1 producer membership"}
  ],
  "disposable_counts": {"likes": 5, "follows": 8}
}
```

- Compute from actual associations and any external obligations.
- Prefer stable machine-readable codes over parsing strings.
- Distinguish **zero dependencies**, **disposable-only**, **blocking**, and **unknown/unclassified**.
- **Fail closed** if dependency inventory is incomplete or a relationship cannot be verified.
- Admin preview must not be treated as final authority; re-evaluate at execution time.
- Apply authorization to preview endpoints; avoid exposing sensitive relationship details to unauthorised users.

### AI prompt — Phase 2

```text
Based on the approved dependency inventory, implement a dedicated DeletionPolicy service with structured blocking reasons and disposable counts. Do not use a generic associations.empty? test. Block hard deletion for published/draft content, comments, producer responsibilities, active billing, financial/legal retention, legal holds, last active admin, and any unclassified relationship. Allow disposable-only relationships. Add exhaustive policy specs for each relationship, mixed dependencies, unknown dependencies, and last-admin protection. Provide a read-only admin preview endpoint using existing API conventions and RBAC.
```

## 6. Lifecycle service and transaction safety (Phase 3)

Implement distinct service methods, e.g. `deactivate!`, `soft_delete!`, `restore!`, `hard_delete!`.

**Deactivation:** update state, revoke sessions/tokens, block authentication, retain data.  
**Soft delete:** set deleted timestamp/status, revoke access, remove from ordinary listings, retain references, apply visibility/privacy policy.  
**Restore:** admin-authorized, ensure unique identity and account verification, restore permitted state; avoid restoring obsolete credentials or memberships implicitly.  
**Hard delete:** admin-only, require explicit confirmation, acquire appropriate database locks, re-check blocking dependencies **inside the transaction**, delete only approved disposable relations, then destroy the principal.

Safety requirements:

- Protect against time-of-check/time-of-use races: lock principal and coordinate concurrent creation of blocking relationships; rely on restrictive FKs and handle constraint errors as safe refusal. A row lock alone may not protect against every concurrent insert depending on FK/transaction design.
- Do not use broad `dependent: :destroy` or `ON DELETE CASCADE` for protected content.
- Ensure errors roll back database changes. External cleanup (files/provider data) should use idempotent, retryable after-commit jobs or an outbox; DB transactions cannot atomically include external APIs.
- Record a minimal audit event (actor, action, timestamp, outcome, anonymised or non-reversible target reference as appropriate); do not retain unnecessary personal data solely for auditing.
- Ensure background jobs and caches tolerate a missing account.
- Make repeated deletion requests safe (idempotent or explicit `404/409` semantics).
- Hard deletion may leave legally retained transaction records in a separate retention-safe form; do not claim full erasure if copies remain in logs/backups/providers.

### AI prompt — Phase 3

```text
Implement separate lifecycle service operations for deactivate, soft delete, restore, and hard delete using existing Rails patterns. Hard delete must be admin-only, check the DeletionPolicy again during execution, protect against concurrent writes and FK races, clean only explicitly approved disposable associations, and fail without partial DB deletion. Revoke tokens/sessions on deactivation and soft delete. Add minimal non-PII audit records and safe external cleanup via idempotent after-commit jobs where applicable. Never cascade-delete reviews/articles/comments/producer memberships or financial records. Add transaction, rollback, concurrency, callback, and retry tests.
```

## 7. API and authorization (Phase 4)

Adapt route names to the current API conventions; suggested admin endpoints:

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/users/:id/deletion_preview` | Policy and counts |
| POST | `/admin/users/:id/deactivate` | Deactivate |
| POST | `/admin/users/:id/soft_delete` | Soft delete |
| POST | `/admin/users/:id/restore` | Restore |
| DELETE | `/admin/users/:id` | Hard delete only if eligible |

- Use current RBAC permission scheme, ideally separate `users.manage_lifecycle` and `users.hard_delete` permissions.
- Require a second confirmation step (type user email or explicit confirmation phrase); for highly privileged actions consider reauthentication.
- Return `409 Conflict` with structured reasons when deletion is blocked; use `403` for missing permission.
- Do not allow self-deletion through an admin endpoint unless explicitly designed.
- Log outcomes without storing credentials or sensitive user data.

### AI prompt — Phase 4

```text
Expose lifecycle operations in the Wine Words Rails API using the project's existing controller, route, serializer, and RBAC conventions. Add a deletion-preview endpoint, deactivate, soft-delete, restore, and guarded hard-delete actions. Require a distinct hard-delete permission and explicit confirmation; return structured 409 blocking reasons and correct 403/404 responses. Keep all authorization and policy checks server-side. Add request specs for permitted and forbidden roles, deleted/suspended users, last admin, blocked dependencies, and successful disposable-only hard delete. Document API contracts for the frontend.
```

## 8. React admin interface (Phase 5)

On existing user detail/manage page, display:

- Account status and deleted date (where relevant).
- Counts of blocking and disposable relationships from the backend preview.
- **Deactivate**, **Soft Delete**, **Restore**, and **Hard Delete** only when relevant and authorized.
- Disabled hard-delete button and readable reasons when blocked.
- Confirmation modal describing irreversible deletion, disposable cleanup, and retained external records; require explicit confirmation.
- Refresh preview before confirmation and show server `409` reasons if dependencies changed.
- Success/error feedback and redirect or refresh; never optimistically claim deletion succeeded.
- Admin list filters for active, suspended, deactivated, soft-deleted accounts; hide deleted accounts in ordinary public lists.
- Public author display for soft-deleted accounts must follow the content/privacy policy.

### AI prompt — Phase 5

```text
Implement Wine Words frontend account lifecycle controls on the existing admin user management screens, using established React/Vite components, API clients, auth permissions and styles. Fetch the backend deletion preview; show blocking reasons and disposable counts. Add deactivate, soft delete, restore, and conditional hard delete, with a clear irreversible-action confirmation. Handle 403/404/409 and loading states. Add account-status filters and safe deleted-author presentation where appropriate. Add component/integration tests and update API types. Do not implement deletion decisions client-side.
```

## 9. User-initiated deletion and privacy (Phase 6 — optional, separate release)

- Settings → Account → Request account deletion.
- Verify account ownership/re-authenticate and handle pending subscriptions, payments and producer responsibilities.
- Define whether published content remains attributed, is pseudonymised, or is removed; review contractual and privacy obligations.
- Design anonymisation of name, email, profile, OAuth identifiers and other direct identifiers, subject to legal retention needs.
- Define data retention for logs, backups, R2 assets, email providers, analytics and payment processors; avoid claiming immediate erasure from all systems.
- Consult applicable Australian Privacy Principles, including APP 11, and relevant retention obligations before publishing policy text. This is a product design consideration, not legal advice.

### AI prompt — Phase 6

```text
Design (do not automatically ship) self-service Wine Words account deletion requests. Map authentication, confirmation, subscriptions, published content, producer ownership, anonymisation, legal retention, backups and third-party processors. Propose privacy-safe UX, a deletion request state machine, background processing, user notifications and tests. Separate account deactivation, soft deletion, anonymisation and full erasure. Flag legal-policy decisions for human review.
```

## 10. Testing matrix (Phase 7)

**Unit:** every blocking and disposable association; no relationships; mixed dependencies; last-admin; unknown associations; status transitions; repeated requests.  
**Request/auth:** admin vs non-admin; hard-delete-specific permission; no login or token refresh after deletion; deleted account excluded from ordinary listings.  
**Integration:** reviews/articles retain authorship on soft delete; published content not destroyed; likes/follows/notifications removed on eligible hard delete; producer and subscription guards.  
**Concurrency:** create content while deletion is attempted; FK violations and locks fail safely; no partial cleanup.  
**External:** idempotent cleanup; failures and retries; analytics and background jobs with missing users.  
**Frontend:** button visibility, blocking reasons, confirmation, stale preview, API errors, status filters.  
**Operational:** migration rollback, staging dry run, backups, audit visibility, monitoring.

### AI prompt — Phase 7

```text
Audit the entire account lifecycle feature against the approved dependency inventory. Run Rails model/request/service tests, frontend unit/integration tests, linters and relevant end-to-end tests. Add missing cases for last admin, unclassified associations, race conditions, failed external cleanup, retained authored content, permissions, and duplicate delete requests. Report test commands, pass/fail results, residual risks and any migration/deployment concerns. Do not claim passing tests unless actually executed.
```

## 11. Rollout and deployment (Phase 8)

1. Back up production DB and confirm restore procedure.
2. Merge and deploy additive migration first; check schema/indices.
3. Deploy lifecycle services and preview endpoint with **hard deletion disabled** behind feature flag.
4. Deploy frontend and validate in staging with synthetic accounts representing every dependency category.
5. Verify authorization, audit, soft delete/restore, retention policy and observability.
6. Enable hard deletion for a limited admin cohort, review logs and blocked requests.
7. Enable generally after sign-off; maintain an operational runbook for accidental deletion, restore of soft-deleted accounts, and external cleanup failures.

### AI prompt — Phase 8

```text
Prepare a production rollout checklist and runbook for the Wine Words account lifecycle feature, including migrations, feature flags, staging test accounts, backup verification, admin permissions, logging/monitoring, rollback, soft-delete restoration and hard-delete limitations. Ensure hard deletion is off by default until explicit approval. List manual commands appropriate to this repository without executing destructive production commands.
```

## 12. Definition of done

- [ ] Actual account model and every relationship inventoried and classified.
- [ ] Account statuses and soft deletion persist consistently.
- [ ] Authentication/session revocation enforced server-side.
- [ ] Admin preview returns structured dependency counts and reasons.
- [ ] Disposable-only accounts can be hard-deleted safely.
- [ ] Blocking associations prevent hard deletion with clear `409` responses.
- [ ] Published content and financial/producer responsibilities protected.
- [ ] Last active admin cannot be deleted/deactivated.
- [ ] Authorization and explicit irreversible-action confirmation implemented.
- [ ] Soft delete and restore work and are covered by tests.
- [ ] Concurrency, rollback, external cleanup and audit behaviour tested.
- [ ] Frontend displays actions, status, and blocking reasons correctly.
- [ ] Staging verified and production rollout documented.

## 13. Recommended implementation order

**PR 1:** Discovery/inventory and policy approval.  
**PR 2:** Migration, status and authentication changes.  
**PR 3:** Deletion policy + preview API.  
**PR 4:** Lifecycle services + guarded admin endpoints.  
**PR 5:** Frontend controls and tests.  
**PR 6:** Hard-delete feature flag rollout + operational documentation.  
**Later:** User-initiated deletion/anonymisation and comprehensive data-retention workflows.
