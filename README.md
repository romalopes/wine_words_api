# Wine Words API

Wine Words is a wine discovery, review, and publishing platform. This repository
contains its Ruby on Rails backend, which manages the wine catalogue, accounts,
reviews, articles, uploads, and producer-to-reviewer wine packages. The directory
name `wine_prediction_api` is retained from the project's earlier name.

**Start here:** [Local development and deployment setup](docs/LOCAL_AND_DEPLOYMENT_SETUP.md)
contains the full installation steps, environment variable reference, deployment
instructions, and troubleshooting. This README provides the system overview and a
short local startup path.

For model relationships and workflows, start with the
[architecture documentation](docs/architecture/architecture.md).

## How the system fits together

| Component | Responsibility | Local / hosted runtime |
|---|---|---|
| React + TypeScript + Vite frontend | Browser interface for readers, reviewers, producers, and administrators | Sibling `wine_prediction/` directory on port 5173 / Vercel |
| Rails 8.1 backend | JSON API under `/api/v1`, authentication, permissions, and business workflows; also includes Rails-rendered pages | This repository on port 3000 / Docker on Render |
| PostgreSQL | Application records and search data, including the `pg_trgm` extension | Dedicated development database / hosted PostgreSQL |
| Active Storage + Cloudflare R2 | Images and other uploaded files | R2 is currently selected in both development and production |
| Mail delivery | Password resets, verification, and workflow notifications | Local files / configured transactional email provider |

The frontend calls Rails over HTTP with JWT authentication for authenticated API
requests. Rails reads and writes PostgreSQL records and stores uploaded media
separately in R2.

The main features include:

- Wine catalogue: producers, wines, vintages, grapes, regions, countries, and taste profiles.
- Wine discovery through search, quizzes, and taste matching.
- Reviews, articles, and article projects for organising writing work.
- Wine packages with shipment tracking, review deadlines, and reminders.
- Password and optional social login, user roles, and administration tools.
- Optional subscription billing through Stripe.

Background jobs currently use Rails' in-process `:async` adapter in development
and, because of the final configuration override, production. Redis and a separate
worker are not required for default local startup. Solid Queue is installed, but
production needs configuration changes before a separate worker provides durable
jobs; see the deployment guide.

## Run locally

### 1. Install prerequisites

Use Ruby **3.4.2**, Bundler, PostgreSQL with `pg_trgm` support, PostgreSQL development
headers, and libvips for image processing. To run the frontend, also install
**Node 22.12 or newer within Node 22** and npm. The
[full setup guide](docs/LOCAL_AND_DEPLOYMENT_SETUP.md#install-prerequisites)
includes macOS installation commands and Linux dependency notes.

Commands below assume the API and frontend are sibling directories in your
workspace. If you cloned only the API repository, run backend commands from that
repository's root; the frontend is a separate application.

```bash
cd wine_prediction_api
bundle install
```

### 2. Configure Rails

Create or merge these values into `.env.development.local` in the API directory.
Use your own development database credentials if local PostgreSQL does not support
socket authentication for your OS user.

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
TEST_ACCESS_PASSWORD=replace-with-a-local-only-password
TEST_ACCESS_TOKEN_EXPIRATION=7.days
```

`MAIL_TRANSPORT=file` writes development email to `tmp/mails`. The test-access
password is a shared application gate, separate from your account password.
Leave `SOLID_QUEUE_IN_PUMA` absent: the current Puma configuration enables its
plugin even when the variable contains the string `false`.

For uploads, choose one of these configurations before starting Rails:

- **Use the current R2 configuration:** add the values below for a dedicated
  development bucket. Replace every placeholder with the matching R2 settings.
- **Use local disk:** change `config.active_storage.service` to `:local` in
  [config/environments/development.rb](config/environments/development.rb).
  The disk service already exists in [config/storage.yml](config/storage.yml).
  There is currently no environment variable that switches storage services.

```dotenv
CLOUD_FLARE_R2_ACCESS_KEY_ID=your-development-r2-access-key-id
CLOUD_FLARE_R2_ACCESS_KEY=your-development-r2-secret-access-key
CLOUD_FLARE_R2_BUCKET=your-development-media-bucket
CLOUD_FLARE_R2_ENDPOINT=https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com
```

Keep credentials in ignored local files. Do not overwrite existing environment
files or use production resources for development. Rails loads existing dotenv
files too, and exported shell values take priority. If encrypted credentials are
needed, obtain the matching existing key; a newly generated key cannot decrypt them.
See the [configuration reference](docs/LOCAL_AND_DEPLOYMENT_SETUP.md#4-environment-variable-reference)
for optional social login, mail providers, billing, and tracking settings.

### 3. Create the database and start the API

Confirm that `DATABASE_URL` points to your development database, then run:

```bash
bin/rails db:create db:migrate
bin/rails db:migrate:status
bin/rails server -b 127.0.0.1 -p 3000
```

**Do not run `db:seed` as a routine setup step.** The current
[db/seeds.rb](db/seeds.rb) destroys data in multiple tables. An empty migrated
database allows startup but has no reference or sample records. For populated
local data, use a suitable sanitized backup following the
[database restore guide](docs/DATABASE_BACKUP_AND_RESTORE.md), or review individual
scripts in `db/seeds/` before using them on a disposable database. See the
[seed script guide](docs/DATABASE_SEEDS.md) for each script's effects, prerequisites,
execution order, and commands.

### 4. Start the frontend

In a second terminal, from the workspace root:

```bash
cd wine_prediction
npm ci
```

Create or merge these values into the frontend's `.env.development.local`:

```dotenv
VITE_API_BASE_URL=http://localhost:3000/api/v1
```

```bash
npm run dev
```

Open **http://localhost:5173**, register or log in, and enter your test-access
password when prompted. New accounts do not automatically receive administrator
permissions. Keep backend secrets out of `VITE_*` variables, which are exposed to
the browser. Restart the relevant server after changing its environment settings.

### 5. Check the running system

```bash
curl -i http://localhost:3000/up
lsof -i :3000
lsof -i :5173
```

`/up` checks Rails startup; also verify browser API requests target
`http://localhost:3000/api/v1`, and exercise login, uploads, and password reset
(check `tmp/mails`). Use `localhost:5173` consistently: the API's CORS allowlist
does not automatically allow other hostnames or ports.

## Deploy and operate

The frontend is deployed to **Vercel** and the Rails Docker application to
**Render**, with PostgreSQL and Cloudflare R2 configured separately. Follow the
[deployment guide](docs/LOCAL_AND_DEPLOYMENT_SETUP.md#2-configure-the-api-on-render)
for the actual environment values and rollout checks.

Before deploying, review its documented configuration mismatches: `render.yaml`
is not ready to apply unchanged, the effective production job adapter is `:async`,
and the Docker entrypoint runs `db:prepare`, which can seed an initial database.
The frontend origin must also be allowed in
[config/initializers/cors.rb](config/initializers/cors.rb); setting `FRONTEND_URL`
alone does not configure CORS.

## Documentation map

| Guide | What to use it for |
|---|---|
| [Local development and deployment setup](docs/LOCAL_AND_DEPLOYMENT_SETUP.md) | Complete local startup, Vercel/Render configuration, environment variables, and troubleshooting |
| [Architecture and model lifecycles](docs/architecture/architecture.md) | Domain models, relationships, publication, planning, and end-to-end workflows |
| [System and feature reference](WINE_WORDS_README.md) | Detailed architecture, domain features, API behaviour, and repository layout; consult the setup guide for current runtime configuration |
| [Operational dashboard links](docs/general_info.md) | GitHub, Render, Vercel, and monitoring dashboards |
| [Database seed scripts](docs/DATABASE_SEEDS.md) | Each seed file, run commands, dependency order, and destructive/rerun behaviour |
| [Database backup and restore](docs/DATABASE_BACKUP_AND_RESTORE.md) | Backup workflows, recovery, and restoring development data; database backups do not include uploaded media |
| [Domain setup](docs/wine_words_domain_setup.md) | Custom domains and DNS configuration |
| [Cloudflare, Render, and email setup](docs/webcentral_cloudflare_render_email_setup.md) | Domain and transactional email infrastructure configuration |
| [Email infrastructure migration](docs/email-infrastructure-migration.md) | Email migration context and procedures |
| [Social authentication](docs/social_authentication.md) | Provider setup for Google, Apple, Microsoft, and Facebook login |
| [User account identity](docs/user-account-identity.md) | Account identity and authentication behaviour |
| [Wine packages](docs/architecture/wine_packages.md) | Producer/reviewer package workflow, tracking, and reminders |
