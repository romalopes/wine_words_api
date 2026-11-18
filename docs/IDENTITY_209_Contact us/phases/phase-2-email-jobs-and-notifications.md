# Phase 2 — Email, Background Jobs and Notifications

**Status:** Complete
**Date:** 2026-11-17
**Repository:** `wine_words_api`

---

## 1. Recipient configuration — `app/services/contact_messages/recipients.rb`

* Reads **`CONTACT_NOTIFICATION_EMAILS`** (comma or semicolon separated).
* Trims, downcases, drops blanks, rejects invalid addresses and CR/LF
  header-injection attempts, deduplicates.
* Never raises: an empty result logs an error (outside test) and means "store the
  message, skip email". The message and the in-app notification are unaffected.
* `MAIL_REPLY_TO` is **not** read. It keeps its existing meaning as the Reply-To
  header used by `CustomDeviseMailer` (`lib/mail_sender.rb`).

```env
CONTACT_NOTIFICATION_EMAILS=support@wine-words.com,admin@wine-words.com
MAIL_REPLY_TO=support@wine-words.com   # unchanged application-wide Reply-To
```

## 2. Mailer — `app/mailers/contact_messages_mailer.rb` + views

`ContactMessagesMailer#notification(contact_message_id, recipient_email)`:

| Header | Value |
|---|---|
| `From` | `MailSender.from` (`MAIL_FROM`), shared with every other mailer |
| `To` | exactly one configured recipient — never a shared list, so internal addresses are not disclosed to each other |
| `Reply-To` | the visitor's validated address, so a normal email client replies to them |
| `Subject` | `New contact message — <subject>` with CR/LF stripped (header injection) |

Both parts are provided: `app/views/contact_messages_mailer/notification.html.erb`
and `.text.erb`. The HTML part escapes every user-controlled value (ERB `h`;
verified by a spec asserting `&lt;script&gt;` and no raw `<script>`), the text part
is readable as-is, and both include the deep link
`{FRONTEND_URL}/settings/contact-messages/:id`.

## 3. Jobs — `app/jobs/contact_messages/`

| Job | Behaviour |
|---|---|
| `EmailJob#perform(contact_message_id, recipient_email)` | `deliver_now` for one recipient. `retry_on StandardError, wait: :polynomially_longer, attempts: 4`; `discard_on ActiveRecord::RecordNotFound`. One job per recipient means a retry can never duplicate mail for the others. |
| `NotifyStaffJob#perform(contact_message_id)` | Delegates to `ContactMessages::NotifyStaff`; same retry/discard policy. |

Both are enqueued by `Contact::Messages::Submit` **after** the row is committed,
so no mail is sent inside a transaction and a queue outage cannot lose the
message. Enqueue failures are logged and reported to Sentry while the visitor
still receives the success receipt.

## 4. Staff notifications — `app/services/contact_messages/notify_staff.rb`

* Audience: `User.not_deleted.joins(:roles).where(roles: { name: %w[Admin Editor] })`.
* One `Notification` per recipient: type `contact_message_received`,
  `delivered_at` stamped (immediate in-app visibility), `notifiable` and
  `contact_message` set, `target_path=/settings/contact-messages/:id`,
  `target_label="Contact message from <name>"`.
* Each delivery queues `Notifications::WebPushDeliveryJob`.
* Idempotency: the partial unique index on
  `(recipient_id, contact_message_id, notification_type)` plus a
  `RecordNotUnique` rescue. Running the job twice creates no duplicate rows.
* Per-recipient failures are logged and never stop the remaining recipients.

The React notification feed gained the human label **"Contact message"** and the
`contact_message_received` union member (`src/components/Notifications.tsx`,
`src/types/notification.ts`).

## 5. Tests

| Spec | Covers |
|---|---|
| `spec/services/contact_messages/recipients_spec.rb` | trimming, dedupe, invalid addresses, header injection, blank config, `MAIL_REPLY_TO` ignored |
| `spec/mailers/contact_messages_mailer_spec.rb` | To/CC/BCC, From, Reply-To, sanitised subject, body content, HTML escaping, plain-text readability |
| `spec/services/contact_messages/notify_staff_spec.rb` | Editor/Admin targeting, Readers/Reviewers/deleted excluded, idempotent retries |
| `spec/jobs/contact_messages/email_job_spec.rb` | delivery, message survives a delivery failure + retry scheduled, discarded for a missing row |
| `spec/requests/api/v1/contact_messages_spec.rb` | one email job per recipient, notification job, no-recipient path still stores the message |

All pass (part of the 71-example Phase 1/2/5 run).

## 6. Environment documentation

Documented in `.env.example`: `CONTACT_NOTIFICATION_EMAILS` and the Turnstile
variables (Phase 5). Production values belong in the Render dashboard; nothing is
exposed through a `VITE_` variable.
