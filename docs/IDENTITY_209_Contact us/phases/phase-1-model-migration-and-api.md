# Phase 1 — Model, Migration and API

**Status:** Complete
**Date:** 2026-11-17
**Repository:** `wine_words_api`

---

## 1. Schema

### `contact_messages` — `db/migrate/20261117000001_create_contact_messages.rb`

| Column | Type | Notes |
|---|---|---|
| `name` | string(120) | required |
| `email` | string(254) | required, format-validated, downcased |
| `contact_type` | string(32) | required, server allowlist |
| `subject` | string(180) | required |
| `message` | text | required, plain text, max 10 000 |
| `status` | string(16) | required, default `unread` |
| `read_at` | datetime | stamped on read |
| `archived_at` | datetime | stamped on archive |

Indexes: `status`, `contact_type`, `created_at`, `(status, created_at)`.

### `notifications.contact_message_id` — `db/migrate/20261117000002_add_contact_message_to_notifications.rb`

Nullable FK plus a partial unique index on
`(recipient_id, contact_message_id, notification_type) WHERE contact_message_id IS NOT NULL`.
This is what makes retried notification jobs idempotent at the database level
(the existing package index cannot dedupe rows with a NULL `wine_package_id`).

## 2. Model — `app/models/contact_message.rb`

* `CONTACT_TYPES = general, wine_submission, content, business, support, feedback, other`
* `STATUSES = unread, read, archived`
* `before_validation` normalisation (strip, downcase email and contact type).
* Validations: presence; max lengths 120 / 254 / 180 / 10 000; email format;
  allowlists; explicit CR/LF header-injection check.
* `search(term)` — case-insensitive over name/email/subject with
  `sanitize_sql_like` (a visitor's `%` is a literal, never a wildcard).
* `apply_status!` / `mark_read!` / `mark_unread!` / `archive!`:
  * read stamps `read_at`, unread clears it, archived stamps `archived_at`;
  * changing an archived message to read/unread unarchives it (documented
    recommendation in the plan);
  * every transition is idempotent; an unsupported value raises `ArgumentError`.

`Notification` gained the `contact_message_received` type and a
`contact_message` association.

## 3. Authorization — `app/policies/contact_message_policy.rb`

`index?`, `show?` and `update?` are true only for `user.catalogue_manager?`
(Admin/Editor). Readers and Reviewers are denied; anonymous requests never reach
the policy because `authenticate_user!` answers 401 first.

## 4. Endpoints — `config/routes.rb`

```ruby
namespace :admin do
  resources :contact_messages, only: [ :index, :show, :update ], controller: "contact_messages"
end
resources :contact_messages, only: [ :create ]
```

### Public create — `Api::V1::ContactMessagesController`

* Skips Devise auth, the deleted-account guard and the email-verification lock.
* Permits only `name, email, contact_type, subject, message, turnstile_token, website`.
* Delegates to `Contact::Messages::Submit` (honeypot → Turnstile → validation →
  persist → enqueue).
* Responses:
  * `201 {"status":"received"}` — stored, or a silently discarded honeypot;
  * `422 {"error": "...", "errors": [...], "details": {"email": ["is invalid"]}}`;
  * `422 {"error":"We could not verify your submission…"}` for Turnstile failures.
* No id, recipients, timestamps or delivery state are ever returned.

### Protected inbox — `Api::V1::Admin::ContactMessagesController`

| Endpoint | Behaviour |
|---|---|
| `GET /api/v1/admin/contact_messages` | `status`, `contact_type`, `search`, `page`, `per_page`, `sort` (`created_at/updated_at/read_at/archived_at/subject`), `direction` (`asc/desc`). Always paginated; the envelope also carries `unread_count` (archived excluded). List rows omit the body. |
| `GET /api/v1/admin/contact_messages/:id` | Full detail, including the plain-text body. |
| `PATCH /api/v1/admin/contact_messages/:id` | Accepts only `status` (flat or nested), idempotent; audited as `contact_message.update`. Other fields are ignored. |

Unknown filter values are ignored; an unsupported sort column/direction falls
back to `created_at desc`; `per_page` is capped at 100 by `Api::Paginatable`.

Serialization: `app/serializers/contact_message_serializer.rb`
(`include_message: true` only on detail).

## 5. Tests

Files added:

* `spec/models/contact_message_spec.rb` — allowlists, normalisation, boundaries,
  search escaping, transitions/idempotency.
* `spec/policies/contact_message_policy_spec.rb` — anonymous / Reader / Reviewer /
  Editor / Admin matrix.
* `spec/requests/api/v1/contact_messages_spec.rb` — public create (success,
  minimal response, job fan-out, invalid fields, length limits, honeypot,
  Turnstile failure, ignored internal fields) and the full inbox matrix
  (401/403/200, ordering, filters, search, pagination, sort allowlist,
  transitions, 404, forbidden roles).

Result: **71 examples, 0 failures** across the Phase 1/2/5 specs; `rubocop`
reports no offences on the new files.

Command:

```bash
bundle exec rspec spec/models/contact_message_spec.rb \
  spec/policies/contact_message_policy_spec.rb \
  spec/requests/api/v1/contact_messages_spec.rb
```
