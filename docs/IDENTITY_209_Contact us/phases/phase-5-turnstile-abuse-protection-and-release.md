# Phase 5 — Turnstile, Abuse Protection and Release

**Status:** Complete (code) / operational keys outstanding
**Date:** 2026-11-17
**Repositories:** both

---

## 1. Cloudflare Turnstile (server side)

`app/services/turnstile/verifier.rb`

| Variable | Purpose |
|---|---|
| `TURNSTILE_SECRET_KEY` | Siteverify secret. Blank in production = every submission rejected |
| `TURNSTILE_ENABLED` | `true`/`false`; defaults to enabled in **production only** |
| `TURNSTILE_EXPECTED_HOSTNAMES` | Optional comma-separated widget hostname allowlist |
| `TURNSTILE_EXPECTED_ACTION` | Optional expected action (`contact`) |
| `TURNSTILE_VERIFY_URL` | Override for tests/egress proxy |

Behaviour:

* POST `secret`, `response`, `remoteip` to Siteverify (5 s open/read timeouts);
* success requires `success == true`, an allowed hostname and a matching action;
* **fails closed**: missing secret, missing token, non-2xx, malformed JSON,
  network error and Cloudflare error codes all reject the submission;
* the token and the secret are never logged.

The transport is injected (`NativeClient` by default), so specs verify the logic
without touching the network.

## 2. Rate limiting — `config/initializers/rack_attack.rb`

```ruby
throttle("contact_messages/ip/burst", limit: 5, period: 10.minutes) { … POST /api/v1/contact_messages }
throttle("contact_messages/ip/daily", limit: 20, period: 1.day)     { … POST /api/v1/contact_messages }
```

Registered only outside `test` (the existing convention: specs share one IP), and
`Rack::Attack` is mounted only in production-style environments. Exceeding a
limit returns the default generic `429`.

Client IP comes from `request.remote_ip`, which honours Rails' trusted-proxy
configuration; the edge/proxy chain must be verified on the deployed host
(Render → Cloudflare) before relying on it.

## 3. Honeypot and input abuse

* Honeypot field `website`: hidden from sight and assistive tech, filled only by
  bots. A filled value returns the normal `201` receipt but stores/delivers
  nothing (`Contact::Messages::Submit`).
* Strict parameter allowlist on both endpoints; message bodies are never
  interpolated into SQL or shell commands.
* `sanitize_sql_like` on search input; sort column/direction allowlist.
* `maxLength` on every field plus server-side maximum lengths (120/254/180/10 000)
  and per-request body limits at the edge/proxy.
* Email format validation plus a CR/LF check; the mailer strips CR/LF from the
  subject and never uses the visitor as `From`.

## 4. Privacy and logging

* `:message` added to `config/initializers/filter_parameter_logging.rb`, so
  message bodies are filtered from request logs (`:email`/`:token` already were).
* Operational events are logged without content: submission accepted, honeypot
  discard, Turnstile rejection, recipient-config problems, job failures.
* No message body is written to the notification message, the email subject or
  any list response.

## 5. Deployment checklist

1. Run `bin/rails db:migrate` (two migrations) in the controlled deploy, then
   restart the Rails process so the new column and the initializer changes load.
2. Set in the **API** environment: `CONTACT_NOTIFICATION_EMAILS`,
   `TURNSTILE_SECRET_KEY`, optionally `TURNSTILE_EXPECTED_HOSTNAMES=…` and
   `TURNSTILE_ENABLED=true`.
3. Set in the **frontend build**: `VITE_TURNSTILE_SITE_KEY` (public) and rebuild.
4. Add the production/staging SPA hostnames to the Cloudflare Turnstile widget.
5. Confirm the API can reach `challenges.cloudflare.com`.
6. Confirm the worker processes `ContactMessages::EmailJob` /
   `ContactMessages::NotifyStaffJob` and that failed jobs are monitored.
7. Set `FRONTEND_URL` in the API so email deep links point at the deployed SPA.

Rollback: revert the frontend build and remove the Contact nav item; the API
endpoints can stay (they are inert without traffic). Dropping the two migrations
is reversible (`bin/rails db:rollback STEP=2`) but destroys stored messages.

## 6. Verification performed

* API: `bundle exec rspec` — **1729 examples, 68 failures, 2 pending**. None of
  the failures involve this feature (verified by name): they are pre-existing
  MailSender default-value specs, legacy `Wine`/`Log` model specs, social-auth,
  analytics-ingest and similar suites. Every Contact model/policy/request/mailer/
  service/job spec passes (**71 examples, 0 failures**), and `rubocop` reports no
  offences on all 25 changed/new Ruby files. `bin/rails zeitwerk:check` passes.
* Frontend: `npx vitest run` — **637 tests, 5 failures in 4 files**
  (`ApiHealth`, `ArticleDetail`, `TradeAdminPackageDetail`, `WineList`). Those
  files are untouched by this feature, fail identically in isolation, and are
  pre-existing. The 21 Contact/Turnstile examples all pass; `eslint` is clean on
  every changed file; `tsc` reports no errors in them; `npm run build` succeeds.
* Edge cases covered by specs: missing secret, missing token, invalid token,
  hostname mismatch, action mismatch, Siteverify unreachable/malformed, honeypot,
  oversized fields, unauthorized inbox access, retried jobs and delivery failure
  with the message still persisted.

Note: after deploying the migrations, **restart the Rails process** — an instance
that booted before the new column/table existed raises
`ActiveModel::MissingAttributeError` when writing notifications, and the Rack::
Attack/param-filtering initializer changes only load at boot.

## 7. Outstanding operational items

* Create the Turnstile widget + keys (cannot be generated from code).
* Confirm the Render trusted-proxy chain for `remote_ip`.
* Decide a retention policy with the product owner (no automatic deletion in this
  release, per §6.5).
