# Wine Words — Public Contact Form and Internal Message Inbox

## Implementation plan

**Repositories**
- API: `https://github.com/romalopes/wine_words_api`
- Frontend: `https://github.com/romalopes/wine_words_frontend`

**Stack:** Rails API + React/Vite frontend  
**Feature:** Public contact form, persisted messages, email delivery, internal notifications, and an authenticated inbox for Editors/Admins.

**Status:** Implemented — all phases complete (0–5)
**Date:** 2026-11-17 (implementation)

> **Implementation note:** Phase 0 audited both live repositories and confirmed the
> conventions this feature reuses (Pundit, `ContactMessagePolicy` audience = global
> Admin/Editor, Devise-JWT skip pattern from the Trade portal, existing
> `Notification` + Active Job + `MAIL_FROM` infrastructure). `MAIL_REPLY_TO` was
> verified to be a Reply-To **header**, not a recipient list, so it is untouched;
> delivery recipients come from the new `CONTACT_NOTIFICATION_EMAILS`. Cloudflare
> Turnstile did not exist in either repository and was implemented here. Each
> phase's outcome, files and test evidence are documented under `phases/`:
>
> | Phase | Document | State |
> |---|---|---|
> | 0 — Repository audit & approved design | [`phases/phase-0-repository-audit-and-design.md`](phases/phase-0-repository-audit-and-design.md) | ✅ |
> | 1 — Rails model, migration & API | [`phases/phase-1-model-migration-and-api.md`](phases/phase-1-model-migration-and-api.md) | ✅ |
> | 2 — Email, jobs & notifications | [`phases/phase-2-email-jobs-and-notifications.md`](phases/phase-2-email-jobs-and-notifications.md) | ✅ |
> | 3 — Public React Contact page | [`phases/phase-3-public-react-contact-page.md`](phases/phase-3-public-react-contact-page.md) | ✅ |
> | 4 — Internal Contact Messages inbox | [`phases/phase-4-internal-contact-messages-inbox.md`](phases/phase-4-internal-contact-messages-inbox.md) | ✅ |
> | 5 — Turnstile, abuse protection & release | [`phases/phase-5-turnstile-abuse-protection-and-release.md`](phases/phase-5-turnstile-abuse-protection-and-release.md) | ✅ code / ⏳ Turnstile keys & staging walkthrough |
>
> **Validation summary:** 71 new API examples pass (model, policy, request,
> mailer, service, job) and `rubocop` is clean on every new file; 23 new React
> examples pass and `eslint`/`vite build` are clean. The full API suite shows only
> the pre-existing unrelated failures (MailSender defaults, legacy Wine/Log specs,
> social auth, analytics); the full React suite fails only in five pre-existing
> specs unrelated to this feature. Staging acceptance (§11) still requires the
> operational steps in §9.

---

## 1. Objective

Add a public **Contact** menu item immediately before **About**. Visitors can submit a general enquiry without registering or signing in. Persist each submission in the database, email the configured contact recipients, and create in-app notifications for all active Editors and Admins.

Add **Settings → Contact Messages** for authorized Editors/Admins to search, filter, read, mark unread, and archive incoming messages.

This is an inbox, not a full ticketing or CRM system. Replies remain outside the initial scope and can be sent from the recipient's normal email application.

## 2. Product decisions

| Area | Decision |
|---|---|
| Public access | No account or login required |
| Navigation | Contact immediately before About |
| Contact categories | Server-validated dropdown |
| Persistence | New `contact_messages` table |
| Email recipients | Dedicated `CONTACT_NOTIFICATION_EMAILS` configuration |
| Reply address | Preserve the existing meaning of `MAIL_REPLY_TO`; use the sender's validated address as the message's reply-to where supported |
| Internal notifications | Notify all active users with Editor or Admin role |
| Inbox access | Editors and Admins only |
| Message states | `unread`, `read`, `archived` |
| Delete | No delete action in the initial UI |
| Spam controls | Cloudflare Turnstile, rate limiting, honeypot, validation |
| Reply workflow | Not included initially |
| Attachments | Not included initially |

### Important email configuration distinction

Do not silently reinterpret `MAIL_REPLY_TO` as a comma-separated recipient list if the application already uses it as a reply-to header. Email `Reply-To` and delivery recipients are different concepts.

Preferred configuration:

```env
CONTACT_NOTIFICATION_EMAILS=support@wine-words.com,admin@wine-words.com
MAIL_REPLY_TO=support@wine-words.com
```

**Audit result (Phase 0):** in this application `MAIL_REPLY_TO` is a Reply-To
header (`lib/mail_sender.rb` → `CustomDeviseMailer`), not a recipient list. It was
left unchanged; delivery recipients come only from `CONTACT_NOTIFICATION_EMAILS`,
and the contact mailer sets its own per-message `Reply-To` to the visitor.

If the deployed application currently uses `MAIL_REPLY_TO` as a recipient list, inspect its actual usage before changing anything. Preserve existing behavior and document a safe migration. Parse recipient lists, trim whitespace, reject invalid addresses, remove duplicates, and fail safely when no recipient is configured. Never expose recipient addresses in the public API.

Use the application's existing mail delivery provider and delivery abstraction. Do not introduce another email provider solely for this feature.

## 3. Repository discovery and compatibility rules

Before implementation, inspect both repositories and document the actual conventions. Do not assume names or invent architecture.

### API discovery
- Rails version, Ruby version, database adapter, schema conventions.
- Existing User, Role, permission and account/membership models.
- How active Editors and Admins are identified.
- Existing notification model, notification creation service, unread counts and frontend notification API.
- Existing mailers, delivery jobs, `MAIL_REPLY_TO`, sender configuration and email provider integration.
- Existing Rack::Attack or other rate limiting.
- Existing Cloudflare Turnstile verification patterns, if any.
- Existing API versioning, serializers, pagination, error response format and authorization policy approach.
- Existing test framework and factories/fixtures.

### Frontend discovery
- React/Vite versions, router and layout conventions.
- Public navigation and About route.
- Settings navigation and authorization guards.
- Existing form, validation, API client, toast and loading patterns.
- Existing notification badge/count integration.
- Existing table/list, pagination, filters and responsive design components.
- Existing accessibility and test conventions.

### Non-negotiable compatibility
- Reuse existing roles and permissions; do not create duplicate role systems.
- Reuse the existing notification infrastructure.
- Reuse existing mailer and background-job conventions.
- Keep public submission endpoints separate from protected inbox endpoints.
- Follow current API response and error conventions.
- Do not modify unrelated Wine Words features or subscription behavior.
- Do not add dependencies without explaining why they are necessary.
- Preserve current production configuration and backward compatibility.

---

# 4. Functional requirements

## 4.1 Public Contact page

Route suggestion: `/contact`

Public navigation order must include:

`... | Contact | About`

The page must work for anonymous visitors and authenticated users.

### Form fields

| Field | Required | Suggested constraints |
|---|---:|---|
| Name | Yes | Trimmed; sensible maximum, e.g. 120 characters |
| Email | Yes | Valid email format; maximum 254 characters |
| Contact type | Yes | One of the server-supported values |
| Subject | Yes | Trimmed; maximum 180 characters |
| Message | Yes | Non-empty; maximum 10,000 characters |
| Turnstile token | Yes when enabled | Verified server-side |
| Honeypot | No visible input | Must remain empty |

> **Implemented behaviour for signed-in visitors:** when the visitor has an
> account, the email field is shown read-only with their account address and that
> address is submitted automatically — it is still validated by the API. Anonymous
> visitors enter (and confirm) their own address.

Suggested contact types (stable API values; labels may change):

| API value | Display label |
|---|---|
| `general` | General enquiry |
| `wine_submission` | Wine submission / Producer enquiry |
| `content` | Wine review or article |
| `business` | Business / Partnership |
| `support` | Technical support |
| `feedback` | Feedback / Suggestion |
| `other` | Other |

Do not accept arbitrary category strings from the client. Keep the accepted values in one backend source of truth and expose the available options through a public endpoint or a documented frontend constant kept in sync with the API. Prefer a public metadata endpoint if the application already uses that pattern.

### User experience
- Explain briefly what the form is for.
- Clearly identify required fields.
- Validate on the client for usability and always validate again on the server.
- Prevent duplicate submissions while a request is in progress.
- Show a clear success message only after the API confirms persistence.
- On failure, retain user-entered values where safe and show an actionable error.
- Do not show internal recipient addresses, stack traces, or implementation details.
- Ensure keyboard accessibility, labels, focus states and mobile layout.
- Provide a privacy note explaining that submitted information is used to respond to the enquiry.
- Do not require registration.

## 4.2 Message persistence

Create a `ContactMessage` model and `contact_messages` table.

Suggested fields:

| Column | Type | Notes |
|---|---|---|
| `id` | bigint | Primary key |
| `name` | string | Required |
| `email` | string | Required |
| `contact_type` | string | Required; validated allowlist |
| `subject` | string | Required |
| `message` | text | Required |
| `status` | string | Required; default `unread` |
| `read_at` | datetime | Nullable |
| `archived_at` | datetime | Nullable |
| `created_at` | datetime | Rails timestamp |
| `updated_at` | datetime | Rails timestamp |

Consider adding `email_delivery_status` only if the existing delivery architecture needs durable tracking. Do not store Turnstile tokens, honeypot values or unnecessary request metadata in the message record.

### Model behavior
- Normalize name, email, subject and contact type safely.
- Trim surrounding whitespace.
- Validate required fields and maximum lengths.
- Validate email format.
- Validate contact type against the allowlist.
- Validate status against the supported states.
- Keep message content as plain text; escape it when rendered in HTML.
- Set `read_at` when transitioning to read.
- Clear `read_at` when transitioning back to unread.
- Set `archived_at` when archived.
- Define consistent behavior when an archived message is marked unread or read. Recommended: changing to read/unread unarchives it, unless the product explicitly chooses otherwise.
- Do not hard-delete messages through the initial UI.

### Indexes
Add indexes based on actual query patterns:
- `status`
- `contact_type`
- `created_at`
- Optional composite index for common status/date sorting.

Avoid adding redundant indexes. Confirm the migration against the production database engine and existing conventions.

## 4.3 Public API

Follow the existing API namespace/version and response conventions. Suggested shape (adapt to the repository):

- `GET /api/v1/contact_messages/options` — public supported contact categories, if needed.
- `POST /api/v1/contact_messages` — public submission.

The public create endpoint must:
1. Validate request shape and permitted fields.
2. Verify Turnstile server-side.
3. Apply rate limits.
4. Validate the honeypot.
5. Validate all message fields.
6. Persist the message.
7. Enqueue email delivery and Editor/Admin notifications.
8. Return a minimal success response that does not reveal internal data.

Do not allow public clients to set `status`, `read_at`, `archived_at`, recipient lists, notification recipients or internal fields.

### Transaction and delivery reliability
A message must not be lost because email delivery or notification delivery fails.

Recommended:
- Persist the message first.
- Enqueue delivery work after commit using the application's existing Active Job pattern.
- Make delivery jobs retryable and safe to run more than once.
- Track failures through existing job/error monitoring.
- Avoid sending mail inside a database transaction.
- Ensure job enqueue failure is observable; decide whether the API returns success with an operational alert or a retryable error based on the application's established reliability pattern.
- Consider a transactional outbox only if the current architecture needs stronger delivery guarantees; do not introduce it unnecessarily for this small feature.

## 4.4 Email delivery

Create a mailer, for example `ContactMessageMailer`, using existing mailer conventions.

Email contents:
- Sender name.
- Sender email.
- Contact category (human-readable label).
- Subject.
- Full message.
- Submission timestamp and timezone.
- Link to the authenticated Contact Messages detail page.

Email behavior:
- Send to every configured address in `CONTACT_NOTIFICATION_EMAILS`.
- Set a safe, configured sender address.
- Set `Reply-To` to the validated sender email if supported by current mail configuration.
- Do not use the visitor's email as the SMTP `From` address; this can fail SPF/DMARC and invite spoofing.
- Escape all user-controlled content in HTML email.
- Provide a plain-text alternative.
- Never allow CR/LF header injection.
- Do not include secrets or Turnstile tokens.
- Handle missing/invalid recipient configuration explicitly and log a safe operational error.

Use a background job for delivery. If one recipient fails, decide whether the delivery strategy retries the entire recipient set or tracks recipients independently. Avoid duplicate messages to recipients on retries where possible.

## 4.5 In-app notifications

Notify every active user who currently has the Editor or Admin role.

Reuse the existing notification model and creation service. Inspect whether notifications are per-user records, polymorphic records, or another structure before implementation.

Notification content:
- Title: `New contact message`
- Body: sender name, category and subject (keep it concise).
- Link/target: Contact Message detail route.
- Type/key: use the existing notification type conventions.

Requirements:
- Include all active Editors and Admins.
- Avoid duplicate notifications if a job retries.
- Do not notify inactive, suspended or deleted accounts.
- Do not notify every user with access to a broad account unless the existing role semantics explicitly require it.
- Ensure the existing notification badge/unread count updates through current frontend behavior.
- Do not leak message content to users who lack permission to open the inbox.

---

# 5. Internal inbox and authorization

## 5.1 Navigation

Add **Settings → Contact Messages**.

Show the item only to users authorized as Editor or Admin according to the existing role/permission system. The backend must independently enforce authorization; hiding the menu is not security.

Display an unread count if it fits the existing navigation pattern. Count only messages that are not archived and are unread, unless existing product conventions indicate otherwise.

## 5.2 Protected API

Suggested endpoints; adapt to current routes and conventions:

- `GET /api/v1/admin/contact_messages`
- `GET /api/v1/admin/contact_messages/:id`
- `PATCH /api/v1/admin/contact_messages/:id` — permitted status transitions only.

Potential query parameters:
- `status`
- `contact_type`
- `search` (name, email, subject)
- `page`
- `per_page`
- `sort` (restrict to allowlisted fields/directions)

Do not permit arbitrary SQL sort expressions or unbounded page sizes.

### Authorization matrix

| Action | Anonymous | Reader/Reviewer | Editor | Admin |
|---|---:|---:|---:|---:|
| Submit public contact form | Yes | Yes | Yes | Yes |
| List messages | No | No | Yes | Yes |
| View message | No | No | Yes | Yes |
| Mark read/unread | No | No | Yes | Yes |
| Archive | No | No | Yes | Yes |
| Change recipients/configuration | No | No | No | Existing operational process only |

Confirm whether Editors/Admins are global roles or account-scoped memberships. Apply the existing authorization semantics rather than assuming a global role.

## 5.3 Inbox list page

Features:
- Paginated newest-first list.
- Sender name and email.
- Contact type.
- Subject.
- Submission date/time in the application's chosen timezone convention.
- Read/unread indicator.
- Archived indicator or separate archived filter.
- Search by sender, email and subject.
- Filter by contact type and status.
- Loading, empty, error and retry states.
- Responsive layout for desktop and mobile.
- Accessible table/list semantics.

Suggested status views:
- All
- Unread
- Read
- Archived

Archived messages should not inflate the unread badge.

## 5.4 Message detail page or panel

Display:
- Sender name.
- Sender email (with a safe `mailto:` action if consistent with UI patterns).
- Contact type.
- Subject.
- Full message as escaped plain text.
- Received date/time.
- Current status.

Actions:
- Mark as read.
- Mark as unread.
- Archive.
- Return to inbox.

Mark as read when opened only if that is consistent with the application's UX; otherwise provide an explicit action. Make status changes idempotent.

No inline reply, attachment management, forwarding or permanent deletion in this release.

---

# 6. Security, privacy and abuse prevention

Public forms are an abuse target. Implement layered controls.

## 6.1 Cloudflare Turnstile
- Add frontend site key configuration, e.g. `VITE_TURNSTILE_SITE_KEY`.
- Add backend secret configuration, e.g. `TURNSTILE_SECRET_KEY`.
- Verify tokens on the server using Cloudflare's Siteverify endpoint.
- Validate success, expected hostname and action where configured.
- Treat missing, invalid, expired or replayed tokens as failed verification.
- Never trust a client-side success callback.
- Keep secret keys out of Vite variables and frontend bundles.
- Support development/test configuration without weakening production.
- Use a test verifier/service double in automated tests.
- Document Cloudflare widget hostname and production domain configuration.

If Turnstile is unavailable, fail closed in production unless an explicitly approved operational fallback exists. Do not silently disable verification.

## 6.2 Rate limiting
Use existing Rack::Attack or the application's established rate limiter.

Suggested starting limits (tune using real traffic):
- Per IP: 5 submissions per 10 minutes.
- Per IP: 20 submissions per day.
- Add a separate short burst limit if needed.

Consider shared NATs and legitimate users. Return HTTP 429 with a generic retry message. Do not reveal internal rate-limit keys or infrastructure details.

If the app runs behind Cloudflare/Render or another proxy, verify trusted proxy configuration before relying on client IP headers. Never blindly trust arbitrary `X-Forwarded-For` values.

## 6.3 Honeypot and input abuse
- Add a visually hidden, accessible-safe honeypot field.
- Do not use CSS that makes the field confusing for screen readers.
- Reject or quietly discard submissions with the honeypot populated according to the application's abuse policy.
- Enforce request body and field length limits.
- Reject unsupported content types and malformed payloads.
- Avoid accepting HTML as message content.
- Consider duplicate-message throttling without storing excessive fingerprints.

## 6.4 XSS, injection and email safety
- Render message content as escaped plain text, never trusted HTML.
- Escape content in HTML email templates.
- Do not interpolate user input into SQL or shell commands.
- Validate and normalize email addresses.
- Prevent CR/LF header injection.
- Do not accept recipient addresses from the public request.
- Do not expose stack traces or internal IDs unnecessarily.

## 6.5 Privacy and retention
- Collect only the fields needed to respond.
- Add a concise privacy notice to the form.
- Do not log full message bodies or email addresses unnecessarily.
- Restrict message access to authorized roles.
- Decide a retention policy with the product owner; do not implement automatic deletion in this release.
- Ensure messages are not included in public search, sitemap, analytics event payloads or public API responses.
- Follow the project's privacy policy and applicable Australian privacy obligations as relevant.

## 6.6 Observability
Record operational events without logging sensitive message content:
- Submission accepted/rejected.
- Turnstile verification failure.
- Rate-limit event.
- Email job success/failure.
- Notification job success/failure.
- Unauthorized inbox access.
- Unexpected processing errors.

Use existing Sentry/logging/monitoring integration if configured.

---

# 7. Implementation phases and AI coding prompts

Each prompt is intended to be given to Codex/Cline with the relevant repository open. Complete and review one phase before proceeding.

## Phase 0 — Repository audit and implementation design

> **Implemented:** [`phases/phase-0-repository-audit-and-design.md`](phases/phase-0-repository-audit-and-design.md)

**Repositories:** API and frontend  
**Goal:** Confirm the existing architecture and produce a concrete implementation map without changing code.

### Tasks
1. Inspect both repositories and current branch/status.
2. Identify current public navigation and About route.
3. Identify Settings navigation and role guards.
4. Inspect User/Role/permission implementation and determine how to find all active Editors/Admins.
5. Inspect notification models/services/jobs and frontend unread badge.
6. Inspect mailers, delivery jobs, sender/reply-to configuration and all uses of `MAIL_REPLY_TO`.
7. Inspect existing Turnstile and rate-limiting implementation.
8. Identify API route, serializer, pagination and error conventions.
9. Identify test commands and relevant existing tests.
10. Propose exact files to create/change and any compatibility concerns.

### Acceptance criteria
- No code changes.
- Clear map of existing architecture.
- Explicit confirmation of `MAIL_REPLY_TO` semantics.
- Exact authorization approach documented.
- No duplicate notification or email systems proposed.
- Any assumptions or blockers listed.

### AI prompt

```text
You are working on the Wine Words application.

Repositories:
- API: https://github.com/romalopes/wine_words_api
- Frontend: https://github.com/romalopes/wine_words_frontend

We need to plan a public Contact form and an internal Contact Messages inbox.

Do an architecture audit only. Do not modify files.

Inspect:
1. Rails version, models, roles, permissions, API routes and response conventions.
2. How active Editors and Admins are identified, including account-scoped role semantics.
3. Existing notifications, notification jobs/services, unread counts and frontend integration.
4. Existing mailers, delivery jobs, provider configuration, sender and every use of MAIL_REPLY_TO.
5. Existing Cloudflare Turnstile verification and rate limiting.
6. React router, public navigation, About page, Settings navigation and authorization guards.
7. Existing forms, validation, API client, pagination, list/table and toast components.
8. Existing test frameworks, factories and test commands.

Return:
- A concise architecture summary with exact file paths.
- Recommended implementation files and changes in each repository.
- Existing services/components that must be reused.
- Security and compatibility risks.
- A proposed endpoint contract.
- A phase-by-phase implementation sequence.

Do not assume conventions. Verify them in the code. Do not create a new role, notification, mail delivery or authorization system.
```

## Phase 1 — Rails model, migration and API

> **Implemented:** [`phases/phase-1-model-migration-and-api.md`](phases/phase-1-model-migration-and-api.md)

**Repository:** `wine_words_api`

### Tasks
1. Create migration and `ContactMessage` model.
2. Add status and contact-type validation using repository conventions.
3. Add indexes.
4. Add public submission endpoint.
5. Add protected inbox index/show/update endpoints.
6. Add policy/authorization checks for Editors/Admins.
7. Add filtering, search, sorting and pagination with safe allowlists.
8. Add status transition behavior and timestamps.
9. Add request/model/policy tests.
10. Document API contract.

### Acceptance criteria
- Anonymous users can submit valid messages.
- Invalid categories and fields are rejected server-side.
- Public users cannot list or read messages.
- Readers/Reviewers cannot access the inbox.
- Editors/Admins can list and view messages.
- Status updates are authorized and idempotent.
- Filtering and pagination are bounded and safe.
- Public response exposes no internal recipients or message-management fields.
- Tests cover all role cases and validation boundaries.

### AI prompt

```text
Implement Phase 1 of the Wine Words Contact feature in the Rails API repository.

First use the architecture findings from Phase 0 and follow the actual repository conventions.

Implement:
- ContactMessage migration and model.
- Fields: name, email, contact_type, subject, message, status, read_at, archived_at, timestamps.
- Server-side allowlist for contact_type:
  general, wine_submission, content, business, support, feedback, other.
- Status values: unread, read, archived.
- Validation, normalization and indexes.
- Public create endpoint for anonymous submissions.
- Protected admin inbox endpoints for list, show and permitted status updates.
- Authorization for active Editors/Admins using existing role semantics.
- Search by name/email/subject, filters by status/type, bounded pagination and safe sorting.
- Consistent API errors and serialization.

Do not implement email or notifications yet; those are Phase 2.

Security:
- Never permit public clients to set status, timestamps, recipient addresses or internal fields.
- Do not expose inbox endpoints to anonymous users, Readers or Reviewers.
- Escape message content when rendered; store it as plain text.
- Avoid SQL injection and unbounded queries.

Tests:
- Model validations and allowed values.
- Anonymous successful submission.
- Invalid and malformed requests.
- Authorization matrix for Anonymous, Reader, Reviewer, Editor and Admin.
- Search, filters, pagination and status transitions.
- Ensure public responses do not leak internal data.

Run relevant tests and lint. Report files changed, migrations, test results and any remaining issues. Do not modify unrelated features.
```

## Phase 2 — Email, background jobs and notifications

> **Implemented:** [`phases/phase-2-email-jobs-and-notifications.md`](phases/phase-2-email-jobs-and-notifications.md)

**Repository:** `wine_words_api`

### Tasks
1. Implement recipient configuration parsing.
2. Preserve and document existing `MAIL_REPLY_TO` semantics.
3. Add `CONTACT_NOTIFICATION_EMAILS` unless audit proves an existing variable already represents the recipient list.
4. Implement `ContactMessageMailer`.
5. Implement background delivery job(s).
6. Notify all active Editors/Admins using the existing notification service.
7. Make jobs retry-safe and avoid duplicate notifications.
8. Add tests for recipient parsing, mail content, job behavior and notification targeting.
9. Add environment-variable documentation.

### Acceptance criteria
- Each configured recipient receives an email.
- Sender email is used as Reply-To, not as From.
- User input is escaped in HTML and available in plain text.
- A mail failure does not delete the persisted contact message.
- All eligible active Editors/Admins receive one notification.
- Inactive users and other roles do not receive notifications.
- Retried jobs do not create duplicate notifications.
- No recipient address or secret is exposed publicly.

### AI prompt

```text
Implement Phase 2 of the Wine Words Contact feature in the Rails API repository.

Reuse the existing mailer, background-job, notification and delivery infrastructure discovered in Phase 0.

Email:
- Send a notification email to all configured contact recipients.
- Prefer CONTACT_NOTIFICATION_EMAILS as a comma-separated environment variable.
- Inspect and preserve the actual existing MAIL_REPLY_TO behavior. Do not repurpose it without a compatibility plan.
- Use the configured application sender address as From.
- Set Reply-To to the validated sender email where supported.
- Include sender, category, subject, message, submission time and authenticated inbox link.
- Provide HTML and plain-text email bodies.
- Escape all user-controlled values and prevent header injection.

Notifications:
- Notify every active Editor and Admin according to existing role/account semantics.
- Reuse the current notification service/model and type conventions.
- Link notifications to the Contact Message detail page.
- Ensure retry-safe behavior and avoid duplicate notifications.

Reliability:
- Persist the ContactMessage before asynchronous delivery.
- Enqueue after commit.
- Use existing retry/error-monitoring patterns.
- A delivery failure must not lose the message.
- Handle missing or invalid recipient configuration explicitly.

Tests:
- Recipient parsing, trimming, deduplication and invalid addresses.
- Email headers, recipients, content and escaping.
- Correct Editor/Admin targeting.
- No notification to inactive users or other roles.
- Retry/idempotency behavior.
- Message remains persisted after delivery failure.

Update environment documentation and run relevant tests. Do not introduce a new email provider or notification framework.
```

## Phase 3 — Public React Contact page

> **Implemented:** [`phases/phase-3-public-react-contact-page.md`](phases/phase-3-public-react-contact-page.md)

**Repository:** `wine_words_frontend`

### Tasks
1. Add Contact navigation item immediately before About.
2. Add `/contact` route.
3. Build responsive form.
4. Implement contact category options matching the API.
5. Integrate API client and server validation errors.
6. Integrate Cloudflare Turnstile.
7. Add honeypot field.
8. Add loading, success, error and retry states.
9. Add accessible labels, keyboard behavior and privacy note.
10. Add component/integration tests.

### Acceptance criteria
- Contact is in the correct menu position.
- Page is accessible without login.
- Form works on mobile and desktop.
- Client validation improves usability but server remains authoritative.
- Turnstile token is sent to the API and never treated as verified by the client.
- Duplicate submission is prevented while pending.
- Success is shown only after confirmed API success.
- Errors are understandable and do not expose internal details.
- No secret key is included in the frontend build.

### AI prompt

```text
Implement Phase 3 of the Wine Words Contact feature in the React/Vite frontend repository.

Inspect and reuse existing routing, navigation, form, validation, API, toast and styling conventions.

Implement:
1. Add Contact immediately before About in the public navigation.
2. Add a public /contact route.
3. Create a responsive Contact form with:
   - Name
   - Email
   - Contact type
   - Subject
   - Message
   - Cloudflare Turnstile
   - Honeypot
4. Use these API category values:
   general, wine_submission, content, business, support, feedback, other.
5. Submit to the public API endpoint from Phase 1.
6. Map server validation errors to the relevant fields.
7. Prevent duplicate submissions while pending.
8. Show clear success, failure and retry states.
9. Include a short privacy notice.
10. Make the form accessible and mobile-friendly.

Turnstile:
- Use VITE_TURNSTILE_SITE_KEY only for the public site key.
- Never include the Turnstile secret in Vite configuration or browser code.
- Send the response token to the backend for Siteverify.
- Handle token expiry, reset and verification failure.
- Do not bypass verification in production.

Test:
- Public route without login.
- Required fields and invalid email.
- Category selection.
- Successful submission.
- API validation and network errors.
- Pending/duplicate submission behavior.
- Turnstile token handling.
- Accessible labels and keyboard interaction.

Run relevant tests, lint and production build. Do not change unrelated navigation or authentication behavior.
```

## Phase 4 — Internal Contact Messages inbox

> **Implemented:** [`phases/phase-4-internal-contact-messages-inbox.md`](phases/phase-4-internal-contact-messages-inbox.md)

**Repository:** `wine_words_frontend`

### Tasks
1. Add Settings → Contact Messages navigation item.
2. Restrict visibility to Editors/Admins.
3. Add protected inbox route and route guard.
4. Build paginated inbox.
5. Add search and filters.
6. Build message detail view.
7. Add read/unread/archive actions.
8. Add unread count using existing notification/navigation patterns where appropriate.
9. Add loading, empty, error and responsive states.
10. Add frontend tests.

### Acceptance criteria
- Only authorized Editors/Admins see and access the inbox.
- Backend authorization remains authoritative.
- List is newest first and paginated.
- Search and filters work together.
- Message detail displays content safely as plain text.
- Status actions update the UI after server confirmation.
- Archived messages are excluded from the unread count.
- Unauthorized users receive the application's normal forbidden behavior.
- Mobile layout remains usable.

### AI prompt

```text
Implement Phase 4 of the Wine Words Contact feature in the React/Vite frontend repository.

Reuse the existing Settings navigation, permission checks, API client, list/table, pagination, filtering, detail, toast and notification patterns.

Add Settings → Contact Messages.

Implement:
- Protected inbox route.
- Authorization visibility for active Editors/Admins.
- Paginated newest-first list.
- Search by sender name, email and subject.
- Filters for unread, read, archived and contact type.
- Message detail view.
- Mark read, mark unread and archive actions.
- Unread count in the Settings menu if consistent with existing UI patterns.
- Loading, empty, error and retry states.
- Responsive desktop/mobile UI.

Use the protected API endpoints from Phase 1. Do not rely on frontend role checks as the only security control.

Message content must be displayed as escaped plain text, not interpreted HTML.

Status changes must be confirmed by the API before presenting success. Handle stale data, failed requests and repeated actions safely.

Tests:
- Editor/Admin access.
- Reader/Reviewer/anonymous access denied.
- List pagination, filters and search.
- Detail display and escaping.
- Read/unread/archive actions.
- Unread count behavior.
- Loading, empty and error states.

Run tests, lint and production build. Do not implement reply, permanent delete or attachment functionality.
```

## Phase 5 — Turnstile, abuse protection, integration and release

> **Implemented:** [`phases/phase-5-turnstile-abuse-protection-and-release.md`](phases/phase-5-turnstile-abuse-protection-and-release.md)

**Repositories:** API and frontend

### Tasks
1. Verify production Turnstile site/secret configuration.
2. Implement or confirm server-side Siteverify.
3. Configure rate limits and trusted proxy handling.
4. Implement and test honeypot behavior.
5. Verify request size and input limits.
6. Test email and notification failure behavior.
7. Verify authorization across all endpoints.
8. Run API and frontend test suites.
9. Test the complete flow in staging.
10. Document deployment, environment variables, rollback and operational checks.

### Acceptance criteria
- Production submissions require successful server-side Turnstile verification.
- Rate limits return HTTP 429 safely.
- Proxy IP handling is correct for the deployed hosting topology.
- Honeypot and malformed requests are handled safely.
- No secret is exposed in frontend assets or logs.
- Email and notification failures are observable and do not lose messages.
- Only Editors/Admins can access message content.
- Complete staging flow passes.
- Existing public pages, authentication, notifications and email delivery continue to work.

### AI prompt

```text
Complete Phase 5 for the Wine Words Contact feature across both repositories.

First inspect the deployment configuration and existing security controls. Do not assume the production proxy or hosting topology.

Security:
- Verify Cloudflare Turnstile server-side using the secret environment variable.
- Validate expected hostname/action where configured.
- Reject missing, invalid, expired and replayed tokens.
- Configure rate limiting using the existing Rack::Attack or equivalent system.
- Suggested initial limits: 5 submissions per IP per 10 minutes and 20 per IP per day; make limits configurable if that matches project conventions.
- Verify trusted proxy configuration before using forwarded client IP headers.
- Add and test a honeypot.
- Enforce request and field size limits.
- Ensure HTML, email headers, SQL and logs are safe.
- Confirm no public route exposes ContactMessage records.

Integration:
- Test public submission through database persistence.
- Test email delivery to all configured recipients.
- Test Editor/Admin notifications.
- Test inbox access and all status transitions.
- Test failed email/notification jobs and retry behavior.
- Test rate limiting and Turnstile failures.
- Verify existing Wine Words authentication, notification and mail features are unaffected.

Deployment:
- Document all environment variables and Cloudflare configuration.
- Provide staging verification steps.
- Provide production rollout and rollback steps.
- Include database migration and background-job considerations.
- Do not print secrets in logs or documentation.

Run all relevant API/frontend tests, linters and production builds. Report exact results, remaining risks and manual production configuration steps.
```

---

# 8. API contract proposal

> **As implemented:** the body is flat (`{ name, email, contact_type, subject,
> message, turnstile_token, website }`) — this application has no params wrapper.
> The inbox returns the shared pagination envelope plus `unread_count`, and the
> public 422 adds `details` (`{ "email": ["is invalid"] }`) so the form can
> highlight fields. Full contract in
> [`phases/phase-1-model-migration-and-api.md`](phases/phase-1-model-migration-and-api.md).

Adapt the exact paths and response envelopes to the existing API.

## Public submission

`POST /api/v1/contact_messages`

Example request:

```json
{
  "contact_message": {
    "name": "Jane Smith",
    "email": "jane@example.com",
    "contact_type": "general",
    "subject": "Question about Wine Words",
    "message": "I would like to know more about the platform.",
    "turnstile_token": "TOKEN",
    "website": ""
  }
}
```

`website` is an example honeypot field. Use the actual field name selected by the implementation. Do not persist it.

Successful response should be minimal, for example:

```json
{
  "message": "Your message has been received."
}
```

Use the application's established status code convention (commonly `201 Created`).

## Protected inbox list

`GET /api/v1/admin/contact_messages?status=unread&contact_type=general&search=jane&page=1&per_page=20`

Return paginated records and metadata using the existing API envelope.

List fields should be limited to what the inbox needs:
- id
- name
- email
- contact_type
- subject
- status
- created_at
- read_at
- archived_at

Do not include the full message body in every list row unless the current API convention requires it.

## Protected detail

`GET /api/v1/admin/contact_messages/:id`

Return all authorized detail fields, including the full plain-text message.

## Protected update

`PATCH /api/v1/admin/contact_messages/:id`

Example:

```json
{
  "contact_message": {
    "status": "archived"
  }
}
```

Only permit the status field. Do not permit client changes to sender identity, message content, timestamps or delivery metadata.

---

# 9. Environment variables and deployment

> **As implemented:** `CONTACT_NOTIFICATION_EMAILS` and the `TURNSTILE_*`
> variables are documented in the API `.env.example`; `VITE_TURNSTILE_SITE_KEY`
> is documented in the frontend `.env.example` and typed in `vite-env.d.ts`.
> Turnstile defaults to enabled in production only and fails closed. Operational
> checklist and rollback: [`phases/phase-5-turnstile-abuse-protection-and-release.md`](phases/phase-5-turnstile-abuse-protection-and-release.md).

Confirm exact naming and configuration conventions during Phase 0.

| Variable | Where | Purpose |
|---|---|---|
| `CONTACT_NOTIFICATION_EMAILS` | Rails API | Comma-separated delivery recipients |
| `MAIL_REPLY_TO` | Rails API | Preserve existing application meaning; inspect before modifying |
| Existing mail sender/provider variables | Rails API | Use current mail delivery configuration |
| `TURNSTILE_SECRET_KEY` | Rails API | Server-side Siteverify |
| `VITE_TURNSTILE_SITE_KEY` | Frontend build | Public Turnstile site key |

### Cloudflare configuration
1. Create or reuse a Turnstile widget.
2. Add the production frontend hostname(s).
3. Add staging hostname(s) if staging is used.
4. Configure the public site key in the frontend build environment.
5. Configure the secret only in the API hosting environment.
6. Confirm the API can reach Cloudflare Siteverify.
7. Never commit either key to source control.

### Hosting configuration
- Set API variables in the API hosting service.
- Set `VITE_TURNSTILE_SITE_KEY` in the frontend build environment and rebuild.
- Ensure the API's CORS policy allows the production frontend origin.
- Ensure the frontend API base URL points to the correct production API.
- Confirm background workers process mail and notification jobs.
- Confirm job failures are monitored.
- Run the database migration as part of the controlled deployment.
- Verify the configured recipient list before enabling the public link.

Do not put API secrets in Cloudflare Pages public variables or any `VITE_` variable.

---

# 10. Testing checklist

> **As implemented:** the automated coverage for every item is mapped in
> [`phases/phase-1-model-migration-and-api.md`](phases/phase-1-model-migration-and-api.md),
> [`phases/phase-2-email-jobs-and-notifications.md`](phases/phase-2-email-jobs-and-notifications.md),
> [`phases/phase-3-public-react-contact-page.md`](phases/phase-3-public-react-contact-page.md)
> and [`phases/phase-4-internal-contact-messages-inbox.md`](phases/phase-4-internal-contact-messages-inbox.md).
> Rate limiting (429) is not exercised in the RSpec environment because the
> throttles are registered only outside `test` — verify it in staging (§11).

## Model and API
- [ ] Valid message is persisted.
- [ ] Missing name/email/type/subject/message rejected.
- [ ] Invalid email rejected.
- [ ] Unsupported contact type rejected.
- [ ] Maximum lengths enforced.
- [ ] Malformed payload rejected.
- [ ] Public create response does not expose internal fields.
- [ ] Anonymous list/detail/update denied.
- [ ] Reader and Reviewer list/detail/update denied.
- [ ] Editor and Admin list/detail/update allowed.
- [ ] Search and filters return correct results.
- [ ] Pagination is bounded.
- [ ] Sorting uses an allowlist.
- [ ] Status timestamps remain consistent.

## Email and notifications
- [ ] Every configured recipient receives an email.
- [ ] Recipient parsing trims whitespace and removes duplicates.
- [ ] Invalid recipient configuration is handled safely.
- [ ] Existing `MAIL_REPLY_TO` behavior is preserved.
- [ ] Sender is not used as the From address.
- [ ] Sender is used as Reply-To where supported.
- [ ] HTML email escapes user content.
- [ ] Plain-text email is readable.
- [ ] Email delivery failure does not delete the message.
- [ ] All active Editors/Admins are notified.
- [ ] Inactive users and other roles are not notified.
- [ ] Retries do not duplicate notifications.

## Frontend
- [ ] Contact appears before About.
- [ ] Contact route is public.
- [ ] Form works on desktop and mobile.
- [ ] Required field and email validation work.
- [ ] Category options match backend allowlist.
- [ ] Pending state prevents duplicate clicks.
- [ ] Success only appears after API confirmation.
- [ ] API errors are displayed safely.
- [ ] Turnstile expiry/reset is handled.
- [ ] Contact Messages appears under Settings for Editors/Admins.
- [ ] Other roles cannot access the route.
- [ ] Search, filters and pagination work.
- [ ] Message content is rendered as text.
- [ ] Read/unread/archive actions work.
- [ ] Archived messages do not inflate unread count.

## Abuse and operational checks
- [ ] Turnstile success accepted.
- [ ] Invalid/expired/missing Turnstile token rejected.
- [ ] Production verification fails closed.
- [ ] Rate limit returns 429.
- [ ] Proxy IP handling is verified.
- [ ] Honeypot behavior works.
- [ ] Request size limits work.
- [ ] No secrets in frontend bundle.
- [ ] No message bodies in routine logs.
- [ ] Job failures are observable.
- [ ] Staging end-to-end flow passes.

---

# 11. Staging acceptance walkthrough

1. Open the Wine Words frontend in a private/incognito browser.
2. Confirm Contact appears before About.
3. Open Contact without logging in.
4. Submit a valid general enquiry.
5. Confirm a success message appears.
6. Confirm one database record exists.
7. Confirm every configured recipient receives the email.
8. Confirm all active Editors/Admins receive an in-app notification.
9. Sign in as a Reader and verify Contact Messages is not available and API access is forbidden.
10. Sign in as an Editor and open Settings → Contact Messages.
11. Search for the submitted sender and subject.
12. Open the message and verify all content is displayed safely.
13. Mark it unread, then read, then archive it.
14. Confirm the unread count and archived filter behave correctly.
15. Test invalid Turnstile, honeypot and rate-limited submissions.
16. Verify failed email delivery does not remove the message and can be retried.
17. Verify existing email and notification features still work.

---

# 12. Release and rollback plan

## Release order
1. Complete Phase 0 audit.
2. Implement and deploy API migration/endpoints.
3. Configure recipient and Turnstile secrets on the API.
4. Deploy frontend with the public Contact page and inbox.
5. Enable the public navigation item.
6. Run the staging acceptance walkthrough.
7. Verify production recipient addresses and job processing.
8. Monitor submissions, delivery failures, 429s and Turnstile failures after release.

## Rollback
- Prefer rolling back frontend exposure first if the public form causes problems.
- Keep already persisted contact messages; do not drop the table during rollback.
- If API code must be rolled back, ensure the database migration remains backward-compatible with the prior application version.
- Do not remove or rotate shared mail/Turnstile settings in a way that breaks other application features.
- Re-enable the feature only after the failure is understood and tested.

---

# 13. Explicitly out of scope

Do not implement these in the initial task:
- Replying to messages inside Wine Words.
- Conversation threads.
- Attachments.
- Ticket assignment or ownership.
- Priority/severity workflows.
- CRM integrations.
- Automatic message deletion.
- Public message lookup.
- Automatic conversion to Wine Submissions or Wine Packages.
- New roles or a new notification framework.
- A new email provider.

These can be considered later based on actual usage.

## Definition of done

The task is complete when a visitor can submit a secure public enquiry, the message is reliably stored, configured recipients receive an email, all active Editors/Admins receive an in-app notification, and authorized staff can manage messages through Settings → Contact Messages — with automated tests, deployment documentation and a successful staging walkthrough.

---

# 14. Implementation record (2026-11-17)

## API (`wine_words_api`)

```text
db/migrate/20261117000001_create_contact_messages.rb
db/migrate/20261117000002_add_contact_message_to_notifications.rb
app/models/contact_message.rb
app/models/notification.rb                                  (type + association)
app/policies/contact_message_policy.rb
app/serializers/contact_message_serializer.rb
app/controllers/api/v1/contact_messages_controller.rb
app/controllers/api/v1/admin/contact_messages_controller.rb
app/services/contact.rb
app/services/contact/messages/submit.rb
app/services/contact_messages/recipients.rb
app/services/contact_messages/notify_staff.rb
app/services/turnstile/verifier.rb
app/mailers/contact_messages_mailer.rb
app/views/contact_messages_mailer/notification.html.erb
app/views/contact_messages_mailer/notification.text.erb
app/jobs/contact_messages/email_job.rb
app/jobs/contact_messages/notify_staff_job.rb
config/routes.rb                                            (public + admin routes)
config/initializers/rack_attack.rb                          (two throttles)
config/initializers/filter_parameter_logging.rb             (:message filtered)
.env.example                                                (recipient + Turnstile vars)
spec/models/contact_message_spec.rb
spec/policies/contact_message_policy_spec.rb
spec/requests/api/v1/contact_messages_spec.rb
spec/mailers/contact_messages_mailer_spec.rb
spec/services/contact_messages/recipients_spec.rb
spec/services/contact_messages/notify_staff_spec.rb
spec/services/turnstile/verifier_spec.rb
spec/jobs/contact_messages/email_job_spec.rb
```

Commands:

```bash
bin/rails db:migrate
bundle exec rspec spec/models/contact_message_spec.rb \
  spec/policies/contact_message_policy_spec.rb \
  spec/requests/api/v1/contact_messages_spec.rb \
  spec/mailers/contact_messages_mailer_spec.rb \
  spec/services/contact_messages spec/services/turnstile \
  spec/jobs/contact_messages
bundle exec rubocop app spec   # clean on every new file
```

## Frontend (`wine_words`)

```text
src/components/Contact.tsx / contact.module.css
src/components/ContactMessages.tsx
src/components/ContactMessageDetail.tsx
src/components/Turnstile.tsx
src/components/AppRoutes.tsx                                (public + inbox routes)
src/components/Header.tsx                                   (Contact before About; Settings item)
src/components/mobile/MoreMenu.tsx                          (Contact; staff link)
src/components/Notifications.tsx / src/types/notification.ts (contact_message_received label)
src/constants/contact.ts / src/constants/roles.ts
src/services/contactApi.ts / src/services/api.ts
src/types/contact.ts
src/vite-env.d.ts / .env.example                            (VITE_TURNSTILE_SITE_KEY)
src/components/Contact.test.tsx
src/components/ContactMessages.test.tsx
src/components/ContactMessageDetail.test.tsx
src/components/Turnstile.test.tsx
```

Commands:

```bash
npx vitest run src/components/Contact.test.tsx src/components/ContactMessages.test.tsx \
  src/components/ContactMessageDetail.test.tsx src/components/Turnstile.test.tsx
npx eslint <changed files>
npm run build
```

## Operational notes

* Restart the Rails server after running the migrations — a process that booted
  before `contact_message_id`/`contact_messages` existed cannot write them
  (`MissingAttributeError`), and initializer changes (Rack::Attack, param
  filtering) only load at boot.
* `CONTACT_NOTIFICATION_EMAILS` may be blank: messages and in-app notifications
  still work; email is skipped and an error is logged.
* Production requires `TURNSTILE_SECRET_KEY` and a matching
  `VITE_TURNSTILE_SITE_KEY`; the API rejects every submission without a verified
  token (fail closed).

