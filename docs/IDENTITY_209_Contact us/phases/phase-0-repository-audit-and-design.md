# Phase 0 — Repository Audit and Approved Design

**Status:** Complete
**Date:** 2026-11-17
**Repositories:** `wine_words_api` (local `wine_words_api/`), React frontend (local `wine_words/`)

---

## 1. Audit findings (verified in code, not assumed)

### API

| Area | Evidence | Consequence for this feature |
|---|---|---|
| Rails 8.1.3 / Ruby 3.4.2 / PostgreSQL | `Gemfile`, `.ruby-version`, `db/schema.rb` | Migrations use `ActiveRecord::Migration[8.1]` |
| Auth | `ApplicationController#authenticate_user!` (Devise-JWT) with `reject_deleted_user!` and `enforce_email_verification!` | The public endpoint skips all three, mirroring `Api::V1::Trade::SubmissionsController` |
| Roles | `Role` enum-backed names (`Admin`, `Editor`, `Reviewer`, `Reader`, `Guest`); `User#catalogue_manager?` = Admin or Editor; `User.not_deleted` | Staff audience = `User.not_deleted.joins(:roles).where(roles: { name: %w[Admin Editor] })` |
| Authorization | Pundit included in `ApplicationController`; `rescue_from Pundit::NotAuthorizedError` → `403 {"error":"Forbidden"}` | New `ContactMessagePolicy`; no parallel permission system |
| Public intake precedent | `Api::V1::Trade::SubmissionsController` + `Trade::Submissions::Create` | Same service object + strict param allowlist pattern |
| Notifications | `Notification` model with a `TYPES` allowlist, `delivered_at`, `target_path`, `target_label`; `Trade::Submissions::NotifyStaff` is idempotent per recipient; `Notifications::WebPushDeliveryJob` | New type `contact_message_received`; notify service mirrors the trade one |
| Mail | `ApplicationMailer default from: MailSender.from`; `lib/mail_sender.rb` reads `MAIL_FROM` and `MAIL_REPLY_TO`; `TradeSubmissionsMailer` + HTML/text views; `deliver_later` | New `ContactMessagesMailer`; per-message `Reply-To` is the visitor |
| `MAIL_REPLY_TO` semantics | `lib/mail_sender.rb` → `CustomDeviseMailer default reply_to: MailSender.reply_to`; also read by `AppSetting` for the email test | **It is a Reply-To header, not a recipient list.** Left untouched; `CONTACT_NOTIFICATION_EMAILS` is new |
| Rate limiting | `config/initializers/rack_attack.rb`; throttles registered outside `test`, middleware only in production-style envs | Two contact throttles added |
| Turnstile | Not implemented anywhere (only referenced by `docs/TurnStile/…`) | Implemented in Phase 5 as a small verifier service |
| API conventions | `Api::Paginatable` envelope `{items, page, per_page, total_count, total_pages}`; `{errors: [...]}` 422; serializers in `app/serializers`; flat JSON params (no params wrapper) | Inbox returns the same envelope plus `unread_count`; public 422 adds field-level `details` |
| Audit log | `Auditable` concern, `audit_actions` class macro | Inbox status changes are audited |
| Tests | RSpec, `Devise::Test::IntegrationHelpers`, `EnvHelpers#with_env`, mailer `:test`, ActiveJob `:test` | New model/policy/request/mailer/service/job specs use the same helpers |

### Frontend

| Area | Evidence | Consequence |
|---|---|---|
| React 19 / Vite 6 / react-router 7 | `package.json`, `src/App.tsx` | Routes are flat `<Route>` entries in `src/components/AppRoutes.tsx` |
| Public nav | `Header.tsx` renders `<NavLink to="/about">About</NavLink>` | Contact inserted immediately before it |
| Mobile nav | `src/components/mobile/MoreMenu.tsx` "About" group | Contact added before About there too |
| Settings nav | Header `settings-menu`; `canManageSettings = isAdmin \|\| canManageWinesRole` (includes Reviewers) | Contact Messages is gated separately with the Admin/Editor helper |
| Role helpers | `src/constants/roles.ts` (`canManageAllPackages` = Admin/Editor) | `canManageContactMessages` aliases it |
| API client | `src/services/apiClient.ts#request<T>`, namespace factories registered in `src/services/api.ts`, `ApiError` + `errorData`/`errorText` utils | New `contactApi` factory; server `details` map onto fields |
| Lists / pagination | `usePagedList`, `Pagination`, `TradeAdminPackagesList` | Inbox reuses all three |
| Tests | Vitest + Testing Library, `vi.spyOn(namespace, …)`, `MemoryRouter` | New component tests follow the same style |

## 2. Approved design

* Public `POST /api/v1/contact_messages`; protected `GET/PATCH /api/v1/admin/contact_messages`.
* `ContactMessage` model + `contact_messages` table; statuses `unread`/`read`/`archived`.
* Delivery is asynchronous: one `ContactMessages::EmailJob` per configured recipient and one `ContactMessages::NotifyStaffJob`.
* Staff audience is global Editors/Admins, matching the rest of the admin surface (roles are global in this application).
* Inbox pages live under Settings: `/settings/contact-messages` and `/settings/contact-messages/:id`.

## 3. Compatibility decisions (deviations from the plan text)

| Plan text | Implementation | Why |
|---|---|---|
| Nested body `{ "contact_message": { … } }` | Flat JSON body | The application has no params wrapper; every endpoint is flat |
| Optional public `/options` endpoint | Documented frontend constant `src/constants/contact.ts` mirroring `ContactMessage::CONTACT_TYPES` | The plan allows a synced constant; the app has no public metadata-endpoint convention |
| Retry-safe notifications | Added `notifications.contact_message_id` + partial unique index | The existing package index cannot dedupe NULL-package rows (Postgres treats NULLs as distinct) |
| Unread count in navigation | Unread badge on the inbox's Unread tab + `unread_count` in the list response | Avoids polling a per-user badge on every page; documented per §5.1 "if it fits" |
| "Add policy/authorization" | `ContactMessagePolicy` (Pundit) | Reuses the app's existing policy system rather than a bespoke controller guard |

## 4. Blockers / assumptions

* Cloudflare Turnstile keys must be created outside the codebase; until `TURNSTILE_SECRET_KEY` is set in production, all public submissions are rejected (fail closed). This is intentional.
* `CONTACT_NOTIFICATION_EMAILS` must be set before enabling the public Contact link, otherwise messages are stored but no email leaves the building (in-app notifications still fire).
* No retention automation is implemented, per §6.5.

