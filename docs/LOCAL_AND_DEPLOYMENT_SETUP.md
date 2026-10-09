# Local development and deployment configuration

Checked against the repository on 8 October 2026. This guide covers the React/Vite
frontend in `wine_prediction/` and Rails API in `wine_prediction_api/`, with Vercel
hosting the frontend, Render hosting the API, PostgreSQL storing data, and Cloudflare
R2 storing Active Storage uploads. Examples contain placeholders, never live secrets.

## Where configuration belongs

| Component | Local configuration | Hosted configuration |
|---|---|---|
| React/Vite | `wine_prediction/.env.development.local` | Vercel project → Settings → Environment Variables |
| Rails | `wine_prediction_api/.env.development.local` | Render API service → Environment |
| Background worker, if enabled | Rails configuration | Its own Render environment, or a shared environment group |
| Database backup workflows | Not required to run the app | GitHub Actions secrets; see [backup guide](DATABASE_BACKUP_AND_RESTORE.md) |

Use app-directory files, not the workspace-root `.env.local`. Vite exposes `VITE_*`
values to browser code and embeds them at build time: put no passwords, database
URLs, R2 secrets, or provider secret keys in Vercel's frontend variables. Restart Vite
after local changes; rebuild/redeploy after Vercel changes. Mode-specific files take
precedence over generic files; process environment values take priority.
[Source: Vite environment variables](https://vite.dev/guide/env-and-mode).

Rails uses `dotenv-rails`; prefer `.env.development.local` for personal overrides,
and check existing `.env.development`/exported values if something unexpected wins.
Do not overwrite existing files wholesale. On Render, enter real values through the
dashboard without surrounding dotenv quotes; the Docker image excludes `.env*` and
`config/master.key`. Keep local env files and keys out of Git.

## 1. Run locally, step by step

### Install prerequisites

Use Ruby **3.4.2** (the version in `.ruby-version` and Dockerfile), Bundler, Node
**22.12 or newer within Node 22**, npm, PostgreSQL, libpq headers, and libvips for
image processing. The frontend's locked development dependencies require a recent
Node version. Use the same Node major in Vercel. PostgreSQL must support `pg_trgm`;
the schema uses this extension.

On macOS, with Homebrew and your preferred Ruby/Node version managers installed:

```bash
brew install postgresql@18 libvips pkg-config libyaml
brew services start postgresql@18
export PATH="$(brew --prefix postgresql@18)/bin:$PATH"
ruby --version
node --version
npm --version
psql --version
```

Select Ruby 3.4.2 and Node 22 in your version managers before continuing. If the `pg`
gem cannot find PostgreSQL, configure Bundler with the installed `pg_config` path.
For Linux, install the corresponding PostgreSQL development headers, compiler,
libyaml development headers, and libvips packages.

### Configure the API

From the workspace root:

```bash
cd wine_prediction_api
bundle install
```

Create or merge the following into `.env.development.local`. The example assumes
local PostgreSQL peer/socket authentication for your OS user. Replace `DATABASE_URL`
if your PostgreSQL installation requires a username/password or TCP host.

```dotenv
DATABASE_URL=postgresql:///wine_words_development
FRONTEND_URL=http://localhost:5173
MAIL_TRANSPORT=file
MAIL_FROM=Wine Words <no-reply@example.test>
MAIL_REPLY_TO=developer@example.test
BILLING_PROVIDER=none
REQUIRE_EMAIL_VERIFICATION=false
WEB_CONCURRENCY=0
RAILS_MAX_THREADS=5
RAILS_LOG_LEVEL=debug

# Choose a private development-only gate password and enter it in the UI.
TEST_ACCESS_PASSWORD=replace-with-a-local-only-password
TEST_ACCESS_TOKEN_EXPIRATION=7.days

# Current development configuration uses R2, just like production.
CLOUD_FLARE_R2_ACCESS_KEY_ID=replace-with-development-r2-access-key-id
CLOUD_FLARE_R2_ACCESS_KEY=replace-with-development-r2-secret-access-key
CLOUD_FLARE_R2_BUCKET=replace-with-development-media-bucket
CLOUD_FLARE_R2_ENDPOINT=https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com
```

Leave `SOLID_QUEUE_IN_PUMA` absent, including from inherited shell variables. Leave
unused provider credentials absent rather than inserting fake nonempty keys.
`MAIL_TRANSPORT=file` writes messages under `tmp/mails`; it does not send real email.
If existing SMTP settings are loaded, the explicit `MAIL_FROM` also prevents the
SMTP configuration's required-value lookup from failing.

Use separate development database and R2 resources. Obtain R2 S3 credentials in
Cloudflare, limited to object read/write on the intended media bucket. The secret
variable is named **`CLOUD_FLARE_R2_ACCESS_KEY`**, not `...SECRET_ACCESS_KEY`.
See [R2 credentials](https://developers.cloudflare.com/r2/api/tokens/).

For a fully local upload setup without R2, deliberately change
`config.active_storage.service` to `:local` in `config/environments/development.rb`.
The local service already exists in `config/storage.yml`. There is currently no env
variable that switches Active Storage services. Keep production on `:cloudflare_r2`.

If encrypted credentials are needed, obtain the existing development/master key
securely and set `RAILS_MASTER_KEY`, or use the existing ignored key file. A new
random key cannot decrypt the repository's encrypted credentials.

### Create the development database

```bash
bin/rails db:create db:migrate
bin/rails db:migrate:status
```

Verify `DATABASE_URL` points to development first. These steps intentionally avoid
`db:seed`: the current `db/seeds.rb` starts by destroying data in multiple tables.
For realistic records, restore a suitable sanitized backup using the
[restore guide](DATABASE_BACKUP_AND_RESTORE.md), then check migrations. Seed scripts
must be reviewed individually and used only on disposable databases. An empty schema
lets the app start but does not supply reference data or useful sample records.

Start Rails in this terminal:

```bash
bin/rails server -b 127.0.0.1 -p 3000
```

Development uses the in-process `:async` job adapter, so no separate worker or Redis
is needed for the default local setup.

### Configure and start the frontend

In a second terminal, from the workspace root:

```bash
cd wine_prediction
npm ci
```

Create/merge `wine_prediction/.env.development.local`:

```dotenv
VITE_API_BASE_URL=http://localhost:3000/api/v1
# Optional: configure matching Google credentials on Rails to enable Google login.
# VITE_GOOGLE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

```bash
npm run dev
```

Open **http://localhost:5173**. Use this hostname consistently: the API's CORS list
contains `localhost:5173`, not every alternative hostname or port. Sign up/log in,
enter the test-access password when prompted, and verify producers load. A newly
registered account does not automatically have administrator permissions.

### Verify local services

```bash
curl -i http://localhost:3000/up
lsof -i :3000
lsof -i :5173
```

Check the browser Network tab: API calls should target `localhost:3000/api/v1`.
Test an upload and download, a password reset (inspect `tmp/mails`), and search.
Frontend checks run from `wine_prediction/`:

```bash
npm run build
npm run typecheck
npm test -- --run
```

These commands are verification options, not a claim that the entire suite passes
on every checkout. Never run tests with a production database connection.

## 2. Configure the API on Render

1. Open the [existing Render service](https://dashboard.render.com/web/srv-d8j9miu47okc73a1b5jg),
   or create a **public Web Service** from the API repository with Docker runtime.
2. Select the directory containing the API Dockerfile. For the standalone
   `wine_words_api` repository this is the repository root; for a combined repository
   set the root directory to `wine_prediction_api` and adjust build paths accordingly.
3. Provision a separate production PostgreSQL database or use your intended hosted
   PostgreSQL provider. Set `DATABASE_URL` to its connection string. Render's internal
   URL is appropriate for compatible services in the same Render network; local tools
   require an externally reachable URL. Confirm required extensions are supported.
4. Add the core production env values below, plus R2 credentials and any optional
   integrations you enable. Obtain `RAILS_MASTER_KEY` securely for the encrypted
   credentials shipped with this app; keep `SECRET_KEY_BASE` stable across instances.
5. Use the Dockerfile's default command (`./bin/thrust ./bin/rails server`) and health
   check `/up`. Thruster fronts Puma; the image exposes port 80. Let the platform and
   container establish their ports; do not blindly force the internal Puma port as
   the public service port. Inspect Render logs if port detection fails.
6. Review migrations before deployment. The current Docker entrypoint runs
   `bin/rails db:prepare` before starting Rails. On an initial database this can run
   seeds, so review the destructive seed file before first boot; prepare the intended
   schema/data deliberately rather than assuming deploy is seed-free.
7. Deploy, verify `https://YOUR_API_HOST/up`, then configure Vercel with that API URL.

Example **Render API** values (replace every placeholder):

```dotenv
RAILS_ENV=production
DATABASE_URL=postgresql://USER:PASSWORD@HOST:5432/DATABASE
RAILS_MASTER_KEY=existing-key-for-this-apps-encrypted-credentials
APP_HOST=YOUR_API_HOST
FRONTEND_URL=https://YOUR_FRONTEND_HOST
MAIL_FROM=Wine Words <verified-sender@YOUR_DOMAIN>
MAIL_REPLY_TO=real-inbox@YOUR_DOMAIN
MAIL_TRANSPORT=brevo
BREVO_API_KEY=your-brevo-api-key
RAILS_LOG_LEVEL=info
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=1
TEST_ACCESS_PASSWORD=your-private-access-password
TEST_ACCESS_TOKEN_EXPIRATION=7.days
REQUIRE_EMAIL_VERIFICATION=false
BILLING_PROVIDER=none
CLOUD_FLARE_R2_ACCESS_KEY_ID=your-production-media-access-key-id
CLOUD_FLARE_R2_ACCESS_KEY=your-production-media-secret-access-key
CLOUD_FLARE_R2_BUCKET=your-production-media-bucket
CLOUD_FLARE_R2_ENDPOINT=https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com
```

Alternatively set `MAIL_TRANSPORT=resend` and `RESEND_API_KEY` instead of Brevo.
Verify the sending domain with the chosen provider before enabling email-dependent
account flows. Configure TLS options on `DATABASE_URL` as required by your provider.

### Current deployment mismatches to resolve deliberately

The checked-in [render.yaml](../render.yaml) is not a reliable ready-to-apply blueprint:
it labels both services `pserv`, which means private service, and uses `releaseCommand`.
A public API uses `type: web`; a worker uses `type: worker`. Current Render fields are
`preDeployCommand` for pre-deploy work and `dockerCommand` for a Docker command override.
Validate/update the blueprint before applying it, or use the dashboard setup above.
[Source: Render Blueprint specification](https://render.com/docs/blueprint-spec).

The effective production job adapter is currently **`:async`**: the final assignment
in `config/environments/production.rb` overrides the earlier `:solid_queue` setting.
Starting `bin/jobs` does not make that async queue durable. To use the intended
Solid Queue worker architecture, first remove that override/configure `:solid_queue`,
then run a separate worker using `bin/jobs` with the same database, signing keys,
R2, mail, frontend URL, and integration variables needed by its jobs. Migrate first.
Until then, in-process jobs may be lost on restarts; verify job-dependent features.

Also, `config/puma.rb` checks whether `SOLID_QUEUE_IN_PUMA` is present, not whether
its value parses as true. **The string `false` still enables the plugin.** Remove
this variable entirely to disable it with the current code; the blueprint currently
sets it to `false`. None of these code/blueprint discrepancies is repaired by this guide.

## 3. Configure the frontend on Vercel

1. Open the [Vercel project](https://vercel.com/romalopes-projects/wine-prediction).
2. Select the actual Vite application directory: `wine_prediction` in a combined
   repository, or `.` when that frontend is the repository root. Do not select the
   separate `react-router/` directory.
3. Set framework to **Vite**, install command `npm ci`, build command `npm run build`,
   output directory `dist`, and a Node version compatible with the lockfile (Node 22).
4. Under **Settings → Environment Variables**, set
   `VITE_API_BASE_URL=https://YOUR_API_HOST/api/v1`. Add optional public social-login
   values from the next section. Set Production and Preview deliberately; use a
   separate staging API/data for previews where possible.
5. Deploy/redeploy so the new values are compiled into the frontend. The existing
   `vercel.json` rewrites SPA paths to `/index.html`; keep it so refreshing
   `/producers` or another nested route works.
6. Configure the frontend domain, then set Rails `FRONTEND_URL` to that exact HTTPS
   origin and add it to the API CORS allowlist. Update provider login origins/callbacks.
7. Test registration/login, API calls, direct route refresh, uploads, email links, and
   any enabled checkout or social sign-in flows.

See [Vite on Vercel](https://vercel.com/docs/frameworks/frontend/vite). Vercel does
not run this Rails backend, and its static frontend does not need `DATABASE_URL`.

## 4. Environment variable reference

“Optional” means needed only for the feature described. All backend variables go in
Rails local env files or Render, never in the Vite frontend. Use production provider
credentials only in production; keep test/sandbox keys and resources separate.

### Frontend: local Vite and Vercel

| Variable | Local / Vercel value and purpose |
|---|---|
| `VITE_API_BASE_URL` | Local `http://localhost:3000/api/v1`; Vercel `https://YOUR_API_HOST/api/v1`. Include `/api/v1`. |
| `VITE_GOOGLE_CLIENT_ID` | Optional Google web OAuth client ID; must match Rails `GOOGLE_CLIENT_ID`. |
| `VITE_APPLE_CLIENT_ID` | Optional Apple Services ID; matches Rails `APPLE_CLIENT_ID`. |
| `VITE_APPLE_REDIRECT_URI` | Optional registered Apple return URL; defaults to browser origin. Use a provider-accepted HTTPS URL; follow the social-auth guide for local testing. |
| `VITE_MICROSOFT_CLIENT_ID` | Optional Microsoft app/client ID; matches Rails value. |
| `VITE_MICROSOFT_TENANT_ID` | Optional tenant ID or `common` (default); align with Rails/provider registration. |
| `VITE_FACEBOOK_APP_ID` | Optional public Facebook app ID; matches Rails value. |
| `VITE_FACEBOOK_GRAPH_VERSION` | Optional; code default `v21.0`. Use a version supported by the configured app and match Rails. |
| `VITE_NEON_AUTH_URL`, `VITE_NEON_AUTH_URL_PRODUCTION` | Present in env templates but not read by current frontend source; not required for current Rails authentication. |
| `VITE_USE_FAKE_AUTH` | Present in existing env files but not consumed by current frontend source. Does not enable a supported fake-login mode. |

### Rails core, URLs, and runtime

| Variable | Local | Render / behavior |
|---|---|---|
| `DATABASE_URL` | Dedicated local PostgreSQL URL | Actual production URL; the only active database selector in `database.yml`. Secret. |
| `RAILS_ENV` | Defaults to development | `production`; Dockerfile already sets it. |
| `RAILS_MASTER_KEY` | Existing key if encrypted credentials are needed | Key for the deployed encrypted credentials; obtain securely, do not regenerate blindly. |
| `SECRET_KEY_BASE` | Usually Rails development default | Stable random secret from secure credentials or env; generate with `bin/rails secret` if explicitly configuring it. JWT uses this secret too; rotation invalidates tokens. |
| `FRONTEND_URL` | `http://localhost:5173` | Frontend HTTPS origin, used for email/reset/verification/checkout links; no `/api/v1`. |
| `APP_HOST` | Usually unnecessary | API hostname only (no scheme/path), for Rails mailer URL generation. Default `example.com` is not usable deployment configuration. |
| `DISABLE_FORCE_SSL` | Not needed in development | Leave absent or `false`; only literal `true` disables production force-SSL. |
| `RAILS_LOG_LEVEL` | `debug` | Prefer `info`; code currently defaults to `debug`. |
| `RAILS_MAX_THREADS` | `5` is a reasonable starting value | Controls Puma threads and configured DB connection limit. Size with worker count and DB capacity. |
| `WEB_CONCURRENCY` | `0` for single-process development | Start at `1`, adjust for RAM/DB capacity; code default 1, blueprint says 2. |
| `PORT` | `3000` by default, or `-p` argument | Platform/Thruster managed; do not blindly copy local port settings. |
| `PIDFILE` | Optional alternate Puma PID file | Usually unset. |
| `SOLID_QUEUE_IN_PUMA` | Leave absent | Leave absent for no embedded worker; even `false` is truthy in the current check. |
| `JOB_CONCURRENCY` | Not used by async queue | Solid Queue worker process count (default 1) only after configuring that adapter. |
| `RAILS_SERVE_STATIC_FILES`, `RAILS_LOG_TO_STDOUT` | Usually unnecessary | Blueprint sets `true`; no explicit env reader for these toggles was found in current app configuration. Verify actual Rails behavior rather than relying on these flags. |

`RAILS_MASTER_KEY` and `SECRET_KEY_BASE` serve different purposes: decryption and
application signing respectively. A signing secret does not decrypt credentials.

### Cloudflare R2 media uploads (local Rails and Render)

Both development and production currently select `:cloudflare_r2`.

| Variable | Configuration |
|---|---|
| `CLOUD_FLARE_R2_ACCESS_KEY_ID` | R2 S3 access key ID for the media bucket. Backend only. |
| `CLOUD_FLARE_R2_ACCESS_KEY` | Matching secret access key. Backend secret. |
| `CLOUD_FLARE_R2_BUCKET` | Exact media bucket name; use separate development/production buckets. |
| `CLOUD_FLARE_R2_ENDPOINT` | Full S3 endpoint copied from Cloudflare, typically `https://ACCOUNT_ID.r2.cloudflarestorage.com`; not a dashboard/public CDN URL. |
| `CLOUD_FLARE_R2_REF` | Account ID for the endpoint fallback when `CLOUD_FLARE_R2_ENDPOINT` is absent. An empty endpoint string overrides the fallback, so remove it rather than leaving it blank. |
| `ACTIVE_STORAGE_PUBLIC` | Used by a health-report check only; does not configure bucket public access or change the storage service. Usually omit. |

Region `auto`, path-style addressing, and checksum options are set in `storage.yml`.
Allow object operations required for upload/read/delete. Browser-to-R2 direct uploads,
if used, also require appropriate bucket CORS; Rails API CORS is a separate setting.
Database backups in `database-backups` do not include these media objects.

### Mail and email verification

| Variable | Configuration |
|---|---|
| `MAIL_TRANSPORT` | Local `file`; production `brevo` or `resend`; also supports `smtp` and `auto`. |
| `BREVO_API_KEY` | Brevo transactional API key when using Brevo. Backend secret. |
| `RESEND_API_KEY` | Resend API key when using Resend. Backend secret. |
| `MAIL_FROM` | Required by current production SMTP-settings initialization even with HTTP mail selected. Use a verified production sender; local example `Wine Words <no-reply@example.test>`. |
| `MAIL_REPLY_TO` | Real receiving inbox in production; also used as the default application test-email setting. |
| `SMTP_ADDRESS` | SMTP server host only if using SMTP; omit for local file transport. |
| `SMTP_PORT` | Default `587`; match mail provider. |
| `SMTP_DOMAIN` | SMTP HELO domain; default `localhost`, use appropriate production domain. |
| `SMTP_USERNAME` | SMTP account username if using SMTP. |
| `SMTP_PASSWORD` | SMTP password/app password if using SMTP; backend secret. |
| `SMTP_AUTHENTICATION` | Default `plain`; match provider. |
| `SMTP_ENABLE_STARTTLS` | `true` by default; only literal `true` enables the current setting. |
| `REQUIRE_EMAIL_VERIFICATION` | Default false; set `true` only once real delivery and frontend verification URLs work. |
| `EMAIL_VERIFICATION_EXPIRATION_HOURS` | Positive validity duration in hours, default `24`. |
| `EMAIL_VERIFICATION_AUTO_SEND_ON_SIGNUP` | Default `true`; automatic sending when verification is required. `false` leaves users to request a resend. |

Automatic mail selection is Brevo → Resend → SMTP → file based on available keys.
An explicit transport without required credentials warns and falls back; inspect logs
and send a real test rather than assuming mail was delivered. `file` is useful locally,
but production container files are not an inbox or durable delivery mechanism.
See [email/domain setup](webcentral_cloudflare_render_email_setup.md).

### Authentication and the private access gate

| Variable | Configuration |
|---|---|
| `TEST_ACCESS_PASSWORD` | Shared private-access gate password; choose different local/production values. Not an account/admin password. |
| `TEST_ACCESS_TOKEN_EXPIRATION` | Duration such as `7.days` (default); controls gate token lifetime. |
| `GOOGLE_CLIENT_ID` | Google OAuth web client ID, same as frontend. |
| `APPLE_CLIENT_ID` | Apple Services ID, same as frontend. |
| `APPLE_TEAM_ID` | Apple developer team identifier for enabled Apple integration. |
| `APPLE_KEY_ID` | Apple signing key identifier. |
| `APPLE_PRIVATE_KEY` | Apple private `.p8` signing key; backend only. Code accepts literal `\n` escapes and converts them to newlines. |
| `MICROSOFT_CLIENT_ID` | Microsoft application/client ID, same as frontend. |
| `MICROSOFT_TENANT_ID` | Tenant ID or `common` (default), matching frontend/provider policy. |
| `FACEBOOK_APP_ID` | Public app ID matching frontend. |
| `FACEBOOK_APP_SECRET` | Facebook app secret, Rails only. |
| `FACEBOOK_GRAPH_VERSION` | Code default `v21.0`; match frontend and provider-supported version. |

These provider settings are optional for password login. Register exact local/production
origins and callbacks with each provider; IDs alone are insufficient. Follow
[social authentication](social_authentication.md) for provider-specific steps.
There is no separate `JWT_SECRET` env reader: Devise JWT uses Rails `secret_key_base`.

### Billing, tracking, and optional language-model search

| Variable | Configuration |
|---|---|
| `BILLING_PROVIDER` | `none` (default) for basic local operation; `manual` or `stripe` for enabled billing. Stripe without its key falls back to manual. |
| `STRIPE_SECRET_KEY` | Stripe test key locally, live key only for live production billing. Backend secret. |
| `STRIPE_WEBHOOK_SECRET` | Signing secret for the specific endpoint/environment; local forwarding and deployed endpoints have different secrets. |
| `STRIPE_PUBLISHABLE_KEY` | Present in env files but no current application env reader was found. Not required by current hosted Checkout flow. |
| `AUSTRALIA_POST_API_KEY` | Optional tracking API credential; without it, package workflow still supports tracking links/manual operation. |
| `AUSTRALIA_POST_TRACKING_URL` | Optional override; default `https://auspost.com.au/mypost/track/#/details/`. |
| `AUSTRALIA_POST_API_URL` | Optional API override; default `https://digitalapi.auspost.com.au/shipping/v1/track`. |
| `OLLAMA_BASE_URL` | Optional model service URL; default `http://localhost:11434`. On Render, localhost means the API container, not your laptop. |
| `OLLAMA_MODEL` | Optional model name, default `llama3.2:3b`; provision the model service/model before using this feature. |
| `BATCH_SIZE`, `MODEL` | One-off search rake-task controls, not normal service settings; default batch size 500, optional model filter. Inspect `lib/tasks/search.rake` before running. |

Stripe webhook route is `/api/v1/webhooks/stripe`; configure that endpoint and its
signing secret in the matching Stripe environment. See
[wine packages](architecture/wine_packages.md) for shipment/tracking behavior.

### Legacy aliases and infrastructure-only variables

| Names | Status |
|---|---|
| `DATABASE_URL_DEV_neon`, `DATABASE_URL_PROD_neon`, `DATABASE_URL_local`, `DATABASE_URL_prod_test_neon` | Convenience names in existing env files, not read by database configuration. Set the selected connection as `DATABASE_URL`. |
| `SUPABASE_S3_ACCESS_KEY_ID`, `SUPABASE_S3_SECRET_ACCESS_KEY`, `SUPABASE_PROJECT_REF`, `SUPABASE_S3_REGION`, `SUPABASE_S3_BUCKET_NAME` | Legacy `supabase` storage service definition; not needed while Active Storage uses Cloudflare R2. |
| `NEON_S3_ACCESS_KEY_ID`, `NEON_S3_SECRET_ACCESS_KEY`, `NEON_S3_REGION`, `NEON_S3_BUCKET_NAME`, `NEON_PROJECT_ID` | Unselected `neon` storage definition; not required for R2 uploads or a Neon PostgreSQL database. |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `R2_ENDPOINT`, `BACKUP_ENCRYPTION_RECIPIENT`, `BACKUP_ENCRYPTION_IDENTITY`, `NEON_DATABASE_URL`, `SUPABASE_DATABASE_URL`, `NEON_RESTORE_TEST_DATABASE_URL`, `SUPABASE_RESTORE_TEST_DATABASE_URL`, `SLACK_WEBHOOK_URL` | GitHub backup/restore workflow secrets, not app deployment requirements. Use the [backup guide](DATABASE_BACKUP_AND_RESTORE.md). |
| `BUNDLE_GEMFILE`, `BUNDLE_DEPLOYMENT`, `BUNDLE_PATH`, `BUNDLE_WITHOUT`, `LD_PRELOAD` | Boot/Docker-managed settings; leave to the existing container configuration. |
| `CI`, `RENDER`, Vite `MODE` | Tool/platform context; not credentials to invent or copy into the other service. |

## 5. CORS, domains, and final checks

`FRONTEND_URL` **does not configure CORS**. The origin allowlist is hard-coded in
[config/initializers/cors.rb](../config/initializers/cors.rb). Add the exact HTTPS
production frontend origin and any intended staging origins there, then deploy Rails.
There is no current `CORS_ORIGINS` env variable. The file currently allows selected
Vercel hosts, including `https://wine-words.vercel.app`, and local port 5173;
a custom domain or arbitrary Vercel preview URL is not automatically allowed.

After configuring both platforms, verify:

1. API `/up` returns success over HTTPS, and browser requests use the intended API.
2. Refreshing frontend `/producers` works, and API requests pass CORS.
3. Registration/login, private access, and expected role permissions work.
4. R2 upload/download works using the intended media bucket.
5. Password-reset and verification messages arrive with the right frontend URL.
6. Enabled social providers accept the deployed origins/callbacks.
7. Stripe uses the intended test/live environment and webhook signature verification.
8. Database backups actually target the deployed database, and media has separate recovery.

| Problem | Check |
|---|---|
| API requests go to localhost on Vercel | Set Production/Preview `VITE_API_BASE_URL`, then rebuild. |
| Browser CORS error | Exact scheme/host/port in Rails allowlist; frontend URL env alone is insufficient. |
| Rails boot says `MAIL_FROM` missing | Set `MAIL_FROM`, even when HTTP mail transport is selected in production. |
| Database connection or migrations fail | Correct `DATABASE_URL`, credentials, network/TLS, and `pg_trgm` privileges. |
| Upload fails | Current service is R2; check `CLOUD_FLARE_R2_*`, bucket permissions and endpoint, not old Supabase values. |
| Messages never arrive | Check resolved transport, API credentials, verified sender, queue behavior, and logs. |
| Worker exists but jobs are not durable | Production's final `:async` assignment overrides Solid Queue; fix adapter configuration first. |
| Unexpected embedded queue process | Remove `SOLID_QUEUE_IN_PUMA`; the string `false` still enables it today. |
| Credentials cannot decrypt | Obtain the matching master/environment key; do not substitute a fresh key. |
| Local search has no results | Empty schema has no sample data; use reviewed development data or a sanitized restore. |

## Related operational guides

- [General dashboard links](general_info.md)
- [Domains and DNS](wine_words_domain_setup.md)
- [Cloudflare, Render, and email](webcentral_cloudflare_render_email_setup.md)
- [Database backup and restore](DATABASE_BACKUP_AND_RESTORE.md)
- [Social authentication](social_authentication.md)
- [User identity](user-account-identity.md)
- [Render Docker deployment reference](https://render.com/docs/docker)
