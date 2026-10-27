# Wine Words — Admin/Editor Account Creation & Invitation Implementation Plan

**Date:** 27 October 2026  
**Status:** Implementation-ready design; source-level verification required before coding.

## 0. Repository review and evidence

- Backend: https://github.com/romalopes/wine_words_api
- Frontend: https://github.com/romalopes/wine_words_frontend
- Public backend README identifies Rails 8.1, JSON API under `/api/v1`, JWT authentication, PostgreSQL, password resets, email verification, role administration, and transactional email.
- Backend README documents `FRONTEND_URL`, `MAIL_TRANSPORT=file`, `MAIL_FROM`, and local emails in `tmp/mails`. It notes that production jobs effectively use the `:async` adapter, not a durable worker, and that `config/initializers/cors.rb` must separately allow frontend origins.
- Frontend repository exposes React/TypeScript/Vite, `src/`, `wrangler.jsonc`, and `VITE_API_BASE_URL` build-time configuration.
- **Inspection limitation:** public repository landing pages and README were inspected, but a complete source checkout could not be obtained in this environment. Exact User schema, controllers, route names, mailer classes, frontend component paths, and authentication internals are **not verified**. Do not assume the proposed names exist. Phase 0 requires source inspection before implementation.

## 1. Goals and acceptance criteria

1. Admin and Editor can create a User/Account with optional email, without selecting a password.
2. Creating an account and sending an invitation are separate operations; optional `send_invitation` on creation may combine them deliberately.
3. Email is mandatory for invitation, but optional for account creation.
4. Invitee receives a Brevo-delivered email containing a single-use, time-limited activation link, creates a password, and can log in.
5. Existing active users and their sessions remain unaffected by migrations.
6. Editor cannot assign Admin/Editor privileges, edit protected privileged users, or circumvent permissions via request payloads.
7. Producer memberships may be attached before activation, subject to existing authorization.
8. Resend revokes previous usable tokens; revoke, expiry, and acceptance are audited.
9. No raw tokens or passwords in database, logs, analytics, error monitoring, or API responses.
10. All changes covered by backend and frontend tests; no destructive seeding.

## 2. Recommended architecture

**Reuse the existing User model and authentication/JWT/password-reset/email infrastructure.** Introduce `AccountInvitation` as a separate lifecycle record unless source inspection reveals an equivalent existing model. Avoid introducing Devise or another auth stack solely for invitations.

### User lifecycle

Prefer `unclaimed`, `active`, `suspended`, `deleted` as account states, or adapt existing status fields. `invited` is an invitation state, not necessarily an account state. Do not add `account_status` if existing fields already represent these states. Existing users must be backfilled to their correct current states before adding restrictive defaults or constraints. Never grant access solely because `password_digest` is present.

### AccountInvitation (conceptual)

- `user_id` foreign key, required.
- `invited_by_id` foreign key to users, nullable for system-generated invitations.
- `email` snapshot (normalized), required.
- `token_digest` (SHA-256 or equivalent of a high-entropy random token), unique and required; no raw token storage.
- `status`: pending/sent/accepted/revoked; derive expiry from `expires_at`, optionally persist expired for reporting.
- `expires_at`, `sent_at`, `accepted_at`, `revoked_at`, `created_at`, `updated_at`.
- Optional `delivery_status`, `delivery_error_code`, `provider_message_id`, `last_delivery_attempt_at` to separate provider acceptance from actual delivery.
- Index on `(user_id, created_at)`; unique index on `token_digest`; enforce at most one valid invitation per account in a transaction/lock, not by a naive partial index involving `NOW()`.

**Security invariants:** 7-day validity; cryptographically random >=32-byte token; constant-time digest comparison where applicable; single use; lock user/invitation on acceptance; invalidate other pending invitations atomically; email must still match current normalized User email; suspended/deleted/active accounts cannot accept an onboarding invite; rate-limit public validation/acceptance and privileged send/resend actions. Never reveal token digests in serializers.

### Authorization matrix

| Operation | Admin | Editor |
|---|---|---|
| Create Reader/Reviewer account | Yes | Yes |
| Create Editor account | Yes | No |
| Create Admin account | Yes | No |
| Edit eligible unclaimed account | Yes | Yes |
| Invite/resend/revoke eligible account | Yes | Yes |
| Change producer memberships | Existing policy | Existing policy only |
| Suspend/delete account | Yes | No |
| Edit Admin/Editor account | Existing Admin policy | No |

Use existing permission service/policies, and check actor and target on every mutation. Enforce role assignment server-side, including nested attributes and bulk updates. Default new account to the least-privileged supported role; do not trust role from client.

## 3. Phase 0 — Source audit (mandatory before any code)

Inspect backend: `app/models/user.rb`, authentication controllers/services, `config/routes.rb`, `db/schema.rb` or `db/structure.sql`, user serializers, users controller, role/permission policy, existing password-reset/verification token logic, Action Mailer classes, Brevo delivery adapter, jobs and queue config, test conventions, account deletion rules, and producer memberships.

Inspect frontend: router, `/users` and `/users/:id`, user API client/types, auth context/store, login/password-reset pages, permission components, form components, notifications, and tests. Verify whether `User` or `Account` is canonical naming.

**Deliverable:** concise audit matrix of actual paths/classes, reused functionality, migration risks, confirmed API prefix, and any decisions that differ from this proposal. Stop and report blockers rather than invent files.

**AI prompt — Phase 0**

> Inspect both Wine Words repositories before writing code. Map the current User/Account schema, auth/JWT/password-reset and verification flows, user CRUD, roles and permissions, producer memberships, email delivery through Brevo, Rails jobs, frontend routing/user pages/API client, and tests. Provide exact file paths and code references. Distinguish existing functionality from gaps. Identify compatibility and migration risks. Do not change code in this phase. Propose the minimum-change implementation and reconcile the rest of this plan with actual code.

## 4. Phase 1 — Database and lifecycle

1. Create branch `feature/account-invitations` in both repositories (or separate coordinated branches).
2. Adapt User lifecycle using existing fields when possible; ensure created-by-admin accounts cannot log in before activation.
3. If needed, add `account_status` with a safe staged migration/backfill for existing active users.
4. Create `account_invitations` with indexes and foreign keys; preserve audit history on resend.
5. Decide how to handle email uniqueness (case-insensitive normalized uniqueness, nullable email, soft-deleted records, existing duplicate cleanup). Prefer DB uniqueness where compatible.
6. Add model validations, associations, status predicates, and expiration logic.
7. Do not put password placeholder values into unclaimed accounts; adapt existing password validation conditionally.
8. Test migration on a restored sanitized database, not production.

**AI prompt — Phase 1**

> Implement only the database/model layer of the account-invitation feature, based on Phase 0 audit. Reuse existing lifecycle and auth fields wherever possible. Add AccountInvitation with hashed tokens, expiry, actor reference, timestamps, statuses and safe indexes. Preserve existing active users, existing authentication, producer memberships and soft-delete behavior. Account creation must permit no password only for privileged-created unclaimed users. Add model/migration tests including case-insensitive duplicate emails, null emails, existing users, soft-deleted accounts, and concurrent invitations. Do not edit frontend or send emails yet. Show changed files and test results.

## 5. Phase 2 — Admin/Editor account creation API

1. Reuse existing `/api/v1` users controller/routes; avoid duplicate resources.
2. Permit name, optional email, and allowed roles; sanitize and validate input.
3. Do not accept `account_status=active`, password, admin role or arbitrary privileged flags from Editor.
4. Use existing producer membership assignment with its own permission checks.
5. Return account and invitation summary without secrets.
6. Optionally support `send_invitation` after successful create; failure to send must not roll back an otherwise valid created account without explicit product decision.
7. Add audit event with actor, target and changes (not sensitive data).

**AI prompt — Phase 2**

> Extend the existing Wine Words users API to let Admin and Editor create unclaimed users without passwords and with optional emails. Enforce the existing authorization model at controller and service levels; Editors may only create Reader/Reviewer accounts and cannot modify privileged accounts or elevate via nested parameters. Reuse producer memberships with their existing policy. Return clear 201/422/403 responses. Keep normal public registration unchanged. Add request/policy tests for each role, missing email, duplicate email, membership assignment and mass-assignment attacks. Show exact routes and example requests after inspecting current code.

## 6. Phase 3 — Invitation issuance, email and delivery

1. Add an invitation service (`issue`, `resend`, `revoke`) with transaction and locking.
2. Only allow invitations for eligible unclaimed users with verified/normalized destination email.
3. Generate a 32+ byte random URL-safe token, persist digest, and pass raw token only to the email job. Avoid leaking job arguments to persistent logs or dashboards; consider encrypted job payloads or a signed token design if necessary.
4. Reuse the existing Brevo HTTP Action Mailer adapter and configured sender. Use `FRONTEND_URL` for absolute links; do not hardcode domains.
5. On resend, invalidate prior pending token(s), then issue a new token; rate-limit repeated sends and log delivery outcomes.
6. Use the existing async adapter initially if appropriate, but document that Render restarts can lose queued work. For reliable delivery, move to durable queue/outbox before production reliance or implement safe retry with reconciliation.
7. Avoid asserting that provider acceptance equals mailbox delivery.
8. Email subject: `You're invited to Wine Words`; include invitation expiry and safe support contact. Never include a password.

**Proposed endpoints (adjust to current routes):**

- `POST /api/v1/users/:id/invitations` — issue.
- `POST /api/v1/users/:id/invitations/resend` — resend.
- `POST /api/v1/users/:id/invitations/revoke` — revoke.
- `GET /api/v1/users/:id/invitations` — admin/editor audit history (policy restricted).

**AI prompt — Phase 3**

> Implement secure invitation issue/resend/revoke in Rails using the existing auth, Brevo mailer and permission architecture. Store only a digest of each random single-use token, expire at 7 days, serialize concurrent resends, and ensure only one usable token exists. Add safe delivery retries and provider failure reporting without leaking credentials. Construct the acceptance URL from configured FRONTEND_URL. Reuse the project's email templates and local MAIL_TRANSPORT=file support. Add request, service and mailer tests, including rate limiting, no-email, suspended/active/deleted users, resend invalidation and Brevo failure. Do not implement the frontend yet.

## 7. Phase 4 — Public invitation acceptance API

1. Provide `GET /api/v1/invitations/validate?token=...` or preferably POST validation to reduce token exposure in URL/access logs; public endpoint should return minimal user display data and generic failure messages.
2. Provide `POST /api/v1/invitations/accept` with token/password/password_confirmation.
3. Validate token digest, expiry, status, account status and email match; lock relevant rows.
4. Reuse existing password policy and password hashing. Do not reset or overwrite password on an already active account.
5. In one transaction set password, activate account, mark invitation accepted, invalidate others, and record audit event.
6. Reuse existing login/JWT issuance safely after commit, or redirect to login if session issuance cannot be reused cleanly.
7. Ensure public endpoints are rate limited and errors do not reveal unnecessary account existence.

**AI prompt — Phase 4**

> Implement public invitation validation and acceptance endpoints in Wine Words Rails. Reuse existing password validation/hashing, account activation and JWT/session logic. Make acceptance single-use and atomic under concurrent requests. Reject expired, revoked, superseded, already-used and email-mismatched tokens, as well as suspended/deleted/active accounts. Never expose token digests or passwords in logs. Return safe structured errors and test all failure cases plus simultaneous acceptance requests. Preserve the existing normal registration, login and password-reset flows.

## 8. Phase 5 — Frontend account creation and user management

1. Add `Create Account` on `/users` only for authorized Admin/Editor.
2. Create form with first/last name, optional email, allowed role, optional producer memberships and `Send invitation immediately` checkbox.
3. Extend `/users` list with account state and invitation state, filters and invite action.
4. Extend `/users/:id` with invitation card: status, last sent, expiry, inviter, resend/revoke buttons, delivery errors, add email when missing.
5. Integrate through existing API client, error handling, auth context and permission components.
6. Never rely on hidden UI buttons as the sole authorization control.

**AI prompt — Phase 5**

> In wine_words_frontend, inspect existing user list/detail pages, routes, API client, role guards, form patterns and styling. Add an Admin/Editor Create Account flow, optional email, role options constrained by server permissions, optional producer membership selection, and explicit Send Invitation option. Add account/invitation status columns, filters and user-detail invitation card with invite/resend/revoke actions and confirmation dialogs. Follow existing React/TypeScript patterns; do not duplicate API clients or introduce a new component library. Add tests for role visibility, form validation, loading/errors and API responses.

## 9. Phase 6 — Frontend acceptance page

1. Add public `/accept-invitation` route outside authenticated guards.
2. Read token once from link; promptly remove from browser URL using `history.replaceState` and avoid third-party analytics/replay on this page.
3. Validate token via backend and display invited email (read-only), optional name fields, password and confirmation.
4. Show expired/invalid/already-used states without leaking account details; suggest contacting inviter/admin for resend.
5. On success use existing auth state and redirect to dashboard or login based on Phase 4 decision.
6. Use `Referrer-Policy: no-referrer` and avoid exposing token in browser telemetry; redact request bodies.

**AI prompt — Phase 6**

> Add the public AcceptInvitation page to Wine Words React. Follow existing routing/auth UI patterns. Securely consume the invitation token, clear it from the address bar, validate it against Rails, show read-only email and a password/confirmation form, and handle invalid/expired/revoked/used states. Integrate successful activation with existing auth/JWT flow without creating a second login mechanism. Disable or redact analytics/Sentry replay/token capture on the sensitive route. Add component and E2E tests for successful and failed acceptance.

## 10. Phase 7 — Account claiming and duplicate handling (optional follow-up)

- If a user registers independently with an email belonging to an unclaimed account, do not create a duplicate or automatically merge based on unverified email.
- Offer a safe, email-verified claiming/invitation flow; reuse invitation acceptance if possible.
- Preserve assigned roles, producer memberships and authored associations.
- For active duplicate emails, retain current registration/password-reset semantics and do not reveal whether an account exists.

**AI prompt — Phase 7**

> Review current signup behavior when an email belongs to an unclaimed account. Design and implement a safe email-verified account claiming flow without auto-merging or bypassing invitation security. Preserve producer memberships and assigned roles. Keep active-account registration behavior and anti-enumeration protections intact. Add regression tests for duplicate registration, race conditions and expired claims.

## 11. Phase 8 — Integration tests, security review and release

### Backend test matrix

- Admin create; Editor create allowed role; Editor privilege escalation rejected; unauthorized user 403.
- Optional email; normalized uniqueness; account created without password; public registration unchanged.
- Invite without email rejected; send/resend/revoke permissions; repeated sends throttled.
- Expiry, replay, tampering, revocation, superseded tokens, changed email, deleted/suspended/active accounts.
- Concurrent resend and concurrent acceptance; exactly one acceptance succeeds.
- Brevo success/failure and retry; email content and configured link; no raw tokens in responses/logs.
- Legacy active users continue login/password reset/social login as before.

### Frontend/E2E test matrix

- Create account, assign producer membership, send invitation, inspect development mail, follow link, choose password, log in.
- Resend invalidates old link; invalid/expired invitation UI; email missing; role-based buttons and API denial.
- Refresh route works on Cloudflare SPA fallback; CORS and auth redirect work on deployed origins.

### Commands (adapt to actual project scripts)

```bash
# Backend
bundle exec rails db:migrate
bundle exec rspec
bundle exec rubocop

# Frontend
npm ci
npm run build
npm run lint
# Use the test command actually defined in package.json.
```

**Never run `db:seed` as a routine setup or deployment check.** The backend README warns that current seeds destroy data in multiple tables. Verify Docker startup's `db:prepare` behavior against the production database before deploying.

### Deployment checklist

1. Create a sanitized backup and verify restore; use NeonDB staging/test, not production for initial migration checks.
2. Deploy backward-compatible DB migration first; verify active users remain active.
3. Deploy Rails API + mailer, then React frontend, then enable invitation buttons via feature flag if available.
4. Set/check `FRONTEND_URL` to the actual production frontend origin; confirm `MAIL_TRANSPORT`, Brevo credentials, `MAIL_FROM`, `MAIL_REPLY_TO` and verified sender domain. No new third-party API key should be needed if Brevo is already configured.
5. Ensure exact Cloudflare/Vercel preview/production origins are in Rails CORS allowlist where necessary.
6. Confirm email delivery on Render, monitor job failures, avoid reliance on non-durable `:async` jobs for critical invites.
7. Test complete invitation flow in staging and one controlled production account.
8. Monitor invite sends/acceptance/error rates via existing Sentry without exposing tokens or personal data.
9. Prepare rollback: disable issuing new invitations, keep database schema backward-compatible, do not discard existing accounts.

**AI prompt — Phase 8**

> Run a full cross-repository review of the account creation/invitation feature. Execute available Rails tests, frontend tests, lint and build; report exact commands and outcomes. Verify privilege boundaries, token secrecy, email retry behavior, race conditions, legacy account compatibility, and producer membership preservation. Review Render/NeonDB/Cloudflare/Brevo deployment settings. Produce a staged release checklist and rollback plan. Do not claim tests passed unless actually run, and do not modify production data or destructive seeds.

## 12. Suggested work breakdown / pull requests

1. `api: account lifecycle and invitation schema`
2. `api: privileged account creation and policies`
3. `api: invitation mailer, issue/resend/revoke`
4. `api: invitation validation and acceptance`
5. `frontend: create-account and invitation management`
6. `frontend: invitation acceptance`
7. `integration: tests, observability, deployment documentation`

Each PR should be reviewable independently, include migrations/tests as applicable, and document any deviations discovered in Phase 0.

## 13. Key decisions before implementation

- Confirm canonical User vs Account model and existing account-status field.
- Confirm password storage/auth library and JWT issuance pattern.
- Confirm whether Admin/Editor role assignments should be stricter than proposed.
- Confirm whether invitation acceptance should auto-login or require normal login (recommend reuse existing login issuance if safe).
- Confirm whether the optional immediate-send checkbox is desirable in v1.
- Decide durable queue/outbox vs existing async delivery for production reliability.

## 14. Master AI prompt

> Implement Wine Words Admin/Editor account creation and secure invitations using the attached plan. Work in small phases and stop after each phase for review. **Start with Phase 0 source audit**: inspect both repositories and replace all provisional file names/routes with real ones. Preserve existing Rails 8.1 JWT authentication, password reset, role/permission model, producer memberships, Brevo HTTP delivery, React/TypeScript UI patterns, NeonDB and Cloudflare deployment. Use a dedicated AccountInvitation model only if equivalent functionality does not exist. No new authentication stack, no raw token storage, no destructive seeds, no unapproved production changes. Enforce backend role restrictions and safe single-use token semantics. For every phase, show changed files, migration/compatibility considerations, tests run, and remaining risks.
