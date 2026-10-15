# Wine Words Observability Implementation Plan

**Scope:** Wine Words API and Wine Words React front end  
**Status:** Implementation plan; no application code or provider configuration has been changed  
**Primary repositories:** [`wine_words_api`](https://github.com/romalopes/wine_words_api) and [`wine_words_front_end`](https://github.com/romalopes/wine_words_front_end)

## 1. Purpose

Add observability to Wine Words in safe, reviewable phases. The first release should make application errors, service health, deploy releases, and basic request performance visible. Later phases can add distributed tracing, structured logs, product metrics, dashboards, and alerts.

The implementation should preserve the two independent repositories and the existing Rails, React/Vite, Render, database, and front-end deployment patterns found in the code. Before implementation, confirm the current deployed front-end provider and production URLs from the repositories and deployment settings; do not assume they have not changed.

## 2. Source material and decisions

This plan consolidates:

- The attached [Sentry React and Rails guide](sentry_setup_ai_prompts_guide.md).
- GitHub [issue #134: Master Observability Implementation Plan](https://github.com/romalopes/wine_words_api/issues/134).
- GitHub [issue #138: implementation checkpoints and safety refinements](https://github.com/romalopes/wine_words_api/issues/138).
- The earlier recommendation to begin with Sentry, Render, Neon and external uptime checks, then add OpenTelemetry/Grafana when the basic monitoring is working.

Issue #134 proposes a larger stack: Sentry for error reporting; OpenTelemetry for telemetry collection; Grafana Cloud for storage, dashboards and alerts; structured logs; traces; business metrics; RUM; release tracking; and tests. Issue #138 adds phase checkpoints, operational thresholds, security reviews, and a requirement that the AI workflow stop after each phase.

This document applies that architecture to **Wine Words only**. The four-repository implementation remains separate: BeachVolleyballHub should receive its own follow-up plan or an adapted copy after the Wine Words implementation is verified.

### Key design choices

1. **Roll out in layers.** Begin with Sentry, hosting/database dashboards, and uptime. Add OpenTelemetry and Grafana after the basic setup is operating.
2. **Keep Sentry and Grafana roles distinct.** Sentry is for error/crash triage and front-end monitoring. OpenTelemetry exports backend traces, logs and metrics to Grafana Cloud.
3. **Never send Grafana private OTLP credentials to browser code.** Browser telemetry should use Sentry or another public-client-safe path. The browser may propagate trace context to the API, but the API alone holds Grafana credentials.
4. **Do not claim end-to-end distributed tracing until it is demonstrated.** A Sentry browser trace and an OpenTelemetry backend trace may be separate traces. Validate propagation and correlation rather than treating package installation as proof.
5. **Use Git SHA as the immutable release identifier.** Apply the same value to Sentry, OpenTelemetry resource attributes, and logs where supported.
6. **Keep telemetry failures non-fatal.** Failure to export telemetry must not prevent Wine Words from starting or serving requests.
7. **Minimize personal data.** Attach stable internal identifiers only when useful; do not send email, IP address, review text, wine-package content, payment data or full request payloads by default.

## 3. Target architecture

| Component | Initial responsibility | Later responsibility |
|---|---|---|
| Sentry Rails project | API exceptions and basic performance | Release/regression alerts and API tracing as appropriate |
| Sentry React project | Browser exceptions and React Error Boundary | Browser tracing/RUM, carefully sampled; source-map symbolication |
| Render dashboard | API logs, CPU, memory, deploys and health | Keep as host-level operational view |
| Neon console (if Neon is the active DB) | Database resource metrics and query history | Continue as database-native reference; avoid duplicate collection without a need |
| External uptime monitor | Check public front-end and API reachability | Alert on outage from outside the hosting provider |
| OpenTelemetry SDK in Rails | None in the first Sentry-only rollout | Rails, ActiveRecord and outbound HTTP traces; logs/metrics if supported and needed |
| Grafana Cloud | None until the OTel phase | Receive OTLP signals, provide cross-service dashboards and alert rules |

If the frontend is deployed as static assets on Cloudflare Pages, browser errors are still captured by Sentry; static hosting does not provide application request logs. If a Cloudflare Worker is running application code, use Cloudflare Worker observability for that runtime as an additional host-level view. Confirm which applies before adding configuration.

## 4. Repositories and service identity

| App | Repository | Proposed service name | Environments |
|---|---|---|---|
| Wine Words API | [`romalopes/wine_words_api`](https://github.com/romalopes/wine_words_api) | `winewords-api` | `development`, `staging` if present, `production` |
| Wine Words front end | [`romalopes/wine_words_front_end`](https://github.com/romalopes/wine_words_front_end) | `winewords-web` | `development`, `staging` if present, `production` |

Use these names consistently in Sentry, OpenTelemetry, and dashboards. Do not merge repositories or share application code between them.

## 5. Reusable AI operating rules

Paste this preamble at the top of each phase-specific prompt:

```text
OPERATING RULES FOR THIS PHASE

This is one independent Wine Words repository. Do not modify another repository.
Work only on the phase requested below. Do not continue to the next phase.

Before editing:
1. Inspect the repository, current branch/status, framework and dependency versions.
2. Find existing Sentry, OpenTelemetry, logging, health-check, request-ID,
   deployment and test configuration. Do not duplicate it.
3. Check current official vendor documentation for the installed versions.
4. Identify compatibility, privacy and deployment risks.
5. State a short implementation plan and wait for my approval before edits if
   the requested change affects production behavior, CORS, secrets, billing,
   or deployment workflows.

During implementation:
- Preserve current business behavior and repository conventions.
- Do not change unrelated code or deployment behavior.
- Do not commit secrets or expose server-side credentials in browser bundles.
- Redact sensitive information and avoid high-cardinality telemetry labels.
- Keep telemetry/export failures from affecting application availability.
- Add meaningful tests and update documentation for this phase only.

At the checkpoint, report files changed, dependencies, environment variables,
manual provider configuration, commands and test results, privacy/security
considerations, deployment steps, and known limitations. Stop and wait.
```

## 6. Phased implementation

### Phase 0 — Repository audit and observability inventory

**Objective:** Establish the actual Wine Words architecture before changing code.

**Steps**

1. Audit the API and front end independently.
2. Record framework/runtime versions, current production and development services, database provider, front-end build/deploy provider, CI workflows, environment variable conventions, logging setup, health routes and existing error reporting.
3. Identify the exact production API base URL and front-end URL from current deployment configuration.
4. Identify whether API exception handling rescues errors, and where authentication/user context is available.
5. Produce a data-flow and secrets inventory, including Stripe, email, OAuth, Cloudflare/R2 and database settings.
6. Recommend an incremental implementation order and file list. Make no edits in this phase.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 0: Perform a read-only observability audit of this Wine Words repository.

Inspect its actual framework/runtime versions, error handling, logging, request
IDs, health routes, environment variables, CI/CD, hosting configuration and
current monitoring. For the API, identify its database adapter and current
Neon/Supabase configuration without printing credential values. For the
front end, identify the actual build tool and current deploy provider; check
whether it is static hosting or a Worker runtime.

Return:
- current architecture and verified deployment facts
- relevant files and existing instrumentation
- sensitive fields that must be scrubbed
- proposed phase-specific changes and tests
- external dashboard/settings steps
- unresolved assumptions

Make no changes.
```

**Checkpoint:** Approve the audit and confirm the exact environment/provider names before Phase 1.

---

### Phase 1 — Create Wine Words Sentry projects and configure secrets

**Objective:** Prepare separate API and browser error projects.

**Steps**

1. Create one Sentry project using the Rails platform for the API.
2. Create one Sentry project using the React/JavaScript platform for the front end.
3. Save each project DSN in the deployment environment for its own app.
4. Use `SENTRY_DSN` for Rails and the Vite public DSN variable (for example, `VITE_SENTRY_DSN`) for the browser. Confirm actual variable prefixes from the repository build setup.
5. Do not put the Sentry auth token or Grafana credentials in application source or frontend environment variables.
6. Decide which environments should report events. Normally, development can be disabled or separated from production; staging should use a distinct environment name.

**Checkpoint:** Confirm the two projects and variables exist; do not paste DSNs or tokens into documentation or chat.

---

### Phase 2 — Add Sentry to the Rails API

**Objective:** Capture unhandled API exceptions and useful, privacy-safe context.

**Steps**

1. Add compatible `sentry-ruby` and `sentry-rails` dependencies after checking the current bundle and official setup guide.
2. Configure the DSN, environment, release and modest production trace sampling in an initializer, using environment variables.
3. Preserve current exception responses and avoid reporting expected 404s or validation failures as server incidents unless useful for product debugging.
4. Add request ID, controller/action, and a stable internal user/account identifier when available. Avoid email, IP and submitted content by default.
5. Scrub passwords, password confirmations, bearer/JWT tokens, authorization/cookie headers, Stripe secrets, OAuth tokens, API keys, database URLs, Cloudflare/R2 credentials and sensitive request data.
6. Add a manual-reporting helper only if rescued exceptions currently disappear from logs and need reporting. Avoid duplicate capture.
7. Keep Sentry initialization optional when no DSN is set, especially for local test runs.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 2: Implement Sentry in the Wine Words Rails API only.

Use the current official Sentry Rails guide compatible with this app's Ruby and
Rails versions. Configure SENTRY_DSN, environment and release through runtime
variables. Capture unhandled server exceptions. Add only useful request/user
context based on existing authentication patterns. Do not attach email, IP,
review/article/wine-package contents, payment information or full request
payloads by default.

Redact passwords, JWTs, authorization/cookie headers, Stripe credentials,
OAuth tokens, API keys, database URLs, Cloudflare/R2 credentials and other
secrets. Do not report expected routing 404s as server failures unless the
existing app has a reason to do so. Keep normal API error responses unchanged
and ensure missing SENTRY_DSN does not break boot or tests.

Add focused tests for initialization behavior and sensitive-data filtering.
Document the required Render variables and a safe test-event procedure. Do not
deploy or modify Render settings.
```

**Checkpoint:** Run the API test suite and a local/test-only event check. Confirm a test error appears in the Wine Words API Sentry project with correct environment and no sensitive data.

---

### Phase 3 — Add Sentry to the React front end

**Objective:** Capture browser runtime errors and React rendering crashes.

**Steps**

1. Add the current compatible Sentry React SDK.
2. Initialize it once at the earliest app entry point.
3. Add an Error Boundary at an appropriate app or route boundary with a helpful fallback that preserves the current design.
4. Add browser tracing only after confirming which API origins should be instrumented. Restrict trace propagation to the Wine Words API and local development origins, not arbitrary third-party hosts.
5. Do not enable broad Session Replay by default. If later enabled, sample conservatively, mask text/input, and block account, payment, review-submission and other sensitive screens/forms. Prefer error-session-only capture if supported and approved.
6. Associate a stable account/user ID only if needed; clear it on logout. Do not send email or profile data by default.
7. Add source-map upload as a later deployment step if the current hosting pipeline supports it; keep the Sentry auth token in CI secrets and prevent public source map exposure if that matters for the app.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 3: Implement Sentry in the Wine Words React front end only.

Inspect the actual React, TypeScript/JavaScript, Vite and router versions first.
Initialize the Sentry React SDK once, add an Error Boundary with a user-friendly
fallback, and configure the environment and release safely. Capture browser
errors and failed application behavior without sending passwords, tokens,
cookies, form fields, review text, payment details or other user content.

If browser tracing is added, restrict tracePropagationTargets to the verified
Wine Words API and local development origins. Do not send credentials or traces
to unrelated third-party origins. Do not enable Session Replay by default; if
there is a supported error-only option, document privacy controls and leave it
disabled until separately approved.

Use the actual deployment provider discovered in this repository. If source
maps are configured, upload them using a CI secret and do not expose the Sentry
auth token or Grafana credentials in the browser bundle. Add focused tests and
document environment variables and verification steps. Do not deploy.
```

**Checkpoint:** Run lint/typecheck/build/tests. Trigger a controlled local browser error and confirm it arrives in the front-end Sentry project.

---

### Phase 4 — Release identity and source-map symbolication

**Objective:** Connect production events to the code revision that produced them.

**Steps**

1. Use the Git commit SHA as `APP_VERSION` for Rails and a build-time release variable for the Vite front end (for example, `VITE_RELEASE`).
2. Set Sentry release from the SHA in both services. Do not generate a random release at runtime.
3. If supported by CI/deployment, upload front-end source maps to Sentry during build; remove or restrict public maps according to the selected deployment workflow.
4. Add service/version and `git.commit.sha` OpenTelemetry resource attributes in the later OTel phase; use the same SHA.
5. Document how Render and the front-end provider receive the release value without changing unrelated deployment behavior.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 4: Add Git-SHA-based release identity to this Wine Words repository.

Inspect the existing CI and deployment pipeline. Use the build/deploy commit SHA
as the immutable release identifier. Configure the correct Rails or Vite
variable and Sentry release; never invent a runtime-random release. If the
front end uses source maps, upload them through the provider's supported build
workflow using a CI-only Sentry auth token. Do not expose that token or change
unrelated deployment behavior.

Add a test or build-time verification for release configuration and document
the provider-side variables. Report any provider limitation rather than
assuming a setting exists. Stop after this phase.
```

**Checkpoint:** Confirm both Sentry projects show the expected release and browser stack traces resolve to source files where source maps are enabled.

---

### Phase 5 — Health checks, Render/Neon baselines and external uptime

**Objective:** Detect outages and distinguish application, hosting and database symptoms.

**Steps**

1. Inspect existing health endpoints. Use a lightweight liveness endpoint for frequent Render checks. Do not expose stack traces, secrets, DB hostnames or configuration.
2. Configure Render HTTP health checks for the API using the verified path. Render uses HTTP health checks to assess whether a web-service instance is ready and responsive. See [Render health checks](https://render.com/docs/health-checks).
3. Keep any database readiness check separate from frequent liveness checks. If Neon autosuspend is enabled, evaluate whether periodic database probes affect compute wake-ups before using one for repeated uptime checks.
4. Review Render logs, CPU, memory and deploy history; add an alert for memory restarts if the account provides it.
5. Review Neon monitoring and query history for CPU/RAM/connections/slow queries when Neon is the active database.
6. Create external uptime checks for the public Wine Words front-end and API health URL. Choose sensible intervals and alert channels; do not rely solely on Render’s own checks.
7. Keep Render and Neon as primary native dashboards initially. Do not forward all logs to another service until there is a concrete retention or cross-service search need.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 5: Review and, if needed, implement safe health-check support for the
Wine Words API.

Inspect existing Rails health routes and current deployment configuration.
Recommend a lightweight liveness URL suitable for frequent Render checks. If a
readiness check queries the database, keep it separate and explain the impact
of frequent checks when Neon compute autosuspend is enabled. Do not expose
credentials or detailed exception output. Do not alter production settings.

Return the exact Render dashboard steps, the external uptime URLs to configure
based on verified deployment facts, and a procedure for checking Render and
Neon metrics. If code changes are necessary, implement only the approved route
and tests, then stop.
```

**Checkpoint:** Verify the health route returns the expected status, Render recognizes it, and an external monitor can reach the public API and front end.

---

### Phase 6 — OpenTelemetry instrumentation in Rails

**Objective:** Collect backend traces without making the API depend on the telemetry vendor.

**Steps**

1. Confirm the project can safely add an OpenTelemetry SDK and OTLP exporter compatible with its Ruby/Rails versions.
2. Start with traces only: Rails/ActionController, ActiveRecord, supported HTTP clients such as Net::HTTP/Faraday, and application request spans.
3. Name the service `winewords-api`; set environment and version/commit SHA as resource attributes.
4. Use environment variables for the OTLP endpoint and headers. Keep Grafana credentials only in Render secrets.
5. Use sampling appropriate for low traffic and cost. Capture errors reliably; sample successful traces rather than exporting every trace by default in production.
6. Ensure exporter errors/timeouts do not fail requests or stop app startup. Add graceful disablement when endpoint credentials are absent.
7. Avoid recording SQL bind values or request bodies; inspect data sent by instrumentations.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 6: Add OpenTelemetry tracing to the Wine Words Rails API, initially for
backend traces only.

Check current official OpenTelemetry Ruby/Rails documentation and compatibility
with this repository. Instrument incoming Rails requests, ActiveRecord and the
HTTP clients actually used. Set service.name=winewords-api plus environment,
service.version and git.commit.sha attributes. Export with OTLP using runtime
variables only. The Grafana token/OTLP authorization header must remain in
Render secrets.

Use conservative production sampling and keep instrumentation/export failures
non-fatal. Do not capture SQL parameters, credentials, request bodies or
sensitive wine/review/subscription data. Do not claim frontend-to-database
trace continuity yet. Add tests using a test exporter/mocks; tests must not
require production Grafana. Document settings and stop after this phase.
```

**Checkpoint:** Verify local/test spans for an API request, a database call and supported outbound HTTP calls. Confirm app boot/request behavior remains healthy when the exporter is disabled or unavailable.

---

### Phase 7 — Browser trace propagation and CORS validation

**Objective:** Pass trace context from browser requests into Rails safely.

**Steps**

1. Choose a single propagation format for the browser-to-API boundary and confirm support in the installed Sentry/OpenTelemetry SDK versions.
2. Allow only the required trace headers in CORS for verified Wine Words front-end origins. Likely candidates include `traceparent` for W3C context and/or Sentry’s `sentry-trace` and `baggage`; include only the headers actually emitted by the chosen setup.
3. Restrict browser trace propagation to the Wine Words API URL(s), not all requests.
4. Confirm Rails continues the incoming trace and exports it to Grafana. If Sentry and Grafana produce separate traces, document that limitation instead of reporting a unified trace.
5. Never export OTLP directly from the browser using Grafana private credentials.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 7: Validate and implement browser-to-Rails trace-context propagation for
Wine Words.

Inspect the frontend request client, Rails middleware/instrumentation and CORS
configuration. Determine the actual headers emitted by the selected tracing
SDKs. Restrict propagation to the verified Wine Words API origins and allow
only the necessary headers in CORS. Do not allow arbitrary origins or expose
Grafana OTLP credentials in browser code.

Add automated tests that verify preflight handling and that incoming context
creates/continues a backend trace. Do not claim that Sentry and Grafana traces
are one unified trace unless the test and dashboards demonstrate it. Document
what is and is not correlated, then stop.
```

**Checkpoint:** Use browser network tools and an API request to verify allowed headers, CORS preflight, trace continuation and no propagation to third-party hosts.

---

### Phase 8 — Structured Rails logs correlated with request and trace IDs

**Objective:** Make production logs searchable and tie them to requests/traces.

**Steps**

1. Preserve human-readable development logs.
2. If Render’s log explorer is sufficient, first add consistent request ID and release fields without changing to JSON. Move to structured JSON only if it makes searching or future Grafana ingestion materially better.
3. If JSON logging is adopted, include timestamp, request_id, trace_id/span_id where available, release, environment, HTTP method, route/controller/action, status, duration and database runtime where safely measurable.
4. Include internal user/account IDs only where operationally needed; use no email or content fields.
5. Never log authorization headers, cookies, tokens, credentials, passwords, payloads or SQL bind values.
6. Preserve Rails logs to stdout/stderr for Render.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 8: Improve Wine Words Rails production log correlation.

First determine whether Render's current log format and existing Rails request
IDs already meet the need. Prefer the smallest change. If structured JSON is
justified, keep development logs readable and produce JSON only in staging and
production. Include timestamp, request_id, trace_id/span_id when available,
release, environment, method, route/controller/action, status and duration.
Include DB runtime only if measured safely.

Do not log request bodies, review/wine-package content, emails, IPs, passwords,
JWTs, authorization/cookie headers, payment data, SQL bind parameters or
credentials. Keep logs on stdout/stderr. Add focused tests for output fields and
redaction. Document the format and stop after this phase.
```

**Checkpoint:** Inspect a test request’s Render log entry and confirm request ID/trace correlation and redaction.

---

### Phase 9 — Configure Grafana Cloud OTLP ingestion

**Objective:** Store and query the backend telemetry exported by OpenTelemetry.

**Steps**

1. Create one Grafana Cloud stack for Wine Words observability.
2. Enable the telemetry signals needed now (initially traces; add logs/metrics when their phases are complete).
3. Configure the OTLP endpoint and authentication headers in Render environment secrets.
4. Confirm the service appears as `winewords-api` and production/development environments are distinguishable.
5. Send a test span and confirm receipt before enabling more telemetry.
6. Document retention/usage limits for the selected plan and inspect volume before increasing sampling.
7. Do not connect the React browser directly to a private Grafana OTLP endpoint.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 9: Prepare Grafana Cloud OTLP ingestion for Wine Words API telemetry.

Use the current official Grafana Cloud OTLP instructions. Provide the exact
manual dashboard steps and environment-variable names, but do not ask me to
paste credentials into code or documentation. Configure endpoint and
authorization only as Render secrets. Enable only signals already implemented
and tested. Use winewords-api service identity and the correct environment.

Verify ingestion with a test trace and explain how to inspect usage/retention.
Do not expose Grafana credentials to the frontend. Stop after documenting the
manual provider configuration.
```

**Checkpoint:** Confirm a test backend trace appears in Grafana Cloud and that disabling exporter configuration does not affect API availability.

---

### Phase 10 — Product metrics (only after technical telemetry is stable)

**Objective:** Add a few useful operational product counters without collecting content or personal data.

**Candidate Wine Words metrics**

| Metric | Event definition to agree before implementation | Suggested type |
|---|---|---|
| `reviews_created` | Increment once when a review is successfully persisted; define whether drafts count | Counter |
| `wines_reviewed` | Increment once when a wine receives its first qualifying published review, or clarify if this is intended as a count of review events | Counter |
| `packages_received` | Increment once when a wine package is marked received, not when a page is viewed | Counter |
| `producer_logins` | Count successful producer logins only if the app has that actor/role and the metric is needed | Counter |

Use low-cardinality labels such as environment and operation. Do not use user ID, wine ID, email, producer name, review text or other unbounded values as metric labels. Avoid duplicate increments across retries or repeated callbacks.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 10: Propose a minimal set of Wine Words product metrics using the current
models and workflows. Do not implement until each event definition is
unambiguous.

Evaluate reviews_created, wines_reviewed, packages_received and
producer_logins. Identify exact successful domain events and whether retries,
drafts, moderation or status changes cause duplicate counts. Use counters or
histograms appropriately, low-cardinality labels only, and service-layer/domain
hooks that match current architecture. Never label metrics with user IDs,
email, wine IDs/names, review content or producer names.

Return definitions and tests first. After approval, implement only agreed
metrics, add no-op behavior when telemetry is disabled, and document them.
```

**Checkpoint:** Review metric definitions before coding. Verify increments exactly once for each agreed event using test exporters.

---

### Phase 11 — Dashboards and alert rules

**Objective:** Turn telemetry into a small set of actionable views and notifications.

**Initial dashboards**

- **API Health:** request rate, error rate, average and p95 latency, slow endpoints, deployment release.
- **Database:** query duration, top/slow queries where available, database runtime and connections. Use Neon’s native dashboard for DB infrastructure metrics unless a Grafana integration is available and worth configuring.
- **Product activity:** only agreed Wine Words metrics from Phase 10.

**Initial alert candidates**

- Sentry: new critical issue, regression, and production error spike.
- Grafana: API availability failure for 2 minutes; latency above 800 ms; error rate above 5%; database timeout/error condition.

These values come from issue #138 and are **initial thresholds**, not permanent SLOs. Alerts should be production-only, include service/environment and useful trace/log links, and avoid percentage alerts when traffic is too low for the percentage to be meaningful. Document why each threshold exists and make it adjustable. Avoid alert loops and duplicate notifications.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 11: Design Wine Words dashboards and alerts from telemetry that is
actually available. Do not invent metric names or assume Grafana data sources
exist.

Create an API Health dashboard for request rate, error rate, average/p95
latency, slow routes and release. Add DB panels only where the data source
supports them. Add product panels only for approved Phase 10 metrics.

Propose production-only alerts using issue #138's initial thresholds:
latency >800ms, error rate >5%, API unavailable for 2 minutes, and database
timeout/error. Treat these as tunable starting values. Suppress percentage
alerts at low traffic, include service and environment, add useful trace/log
links where supported, send email notifications, and prevent duplicates/loops.
Document each alert's reason and tuning method. Return a plan before making
Grafana changes.
```

**Checkpoint:** Review one dashboard and each alert condition in staging/test data before enabling production notifications.

---

### Phase 12 — Automated observability tests

**Objective:** Test instrumentation without relying on production Sentry or Grafana services.

**API checks**

- Sentry initializer handles configured and absent DSN.
- Test exception is captured through a mock/test transport.
- Sensitive fields are filtered.
- OpenTelemetry initializes with test exporter and correct service/environment/release attributes.
- Request context is accepted; child spans and SQL spans are emitted where expected.
- Logs contain request_id and trace ID when available, without secrets.
- Metrics increment once and avoid high-cardinality labels.

**Front-end checks**

- Sentry initializes once with correct environment/release.
- Error Boundary catches a component error.
- API trace headers are limited to intended origins.
- Sensitive form content is not captured.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 12: Add or update automated observability tests for this repository only.

Use mocks, in-memory transports or test exporters; do not require production
Sentry or Grafana credentials. Cover initialization, environment/release,
exception capture, privacy filtering, request/trace IDs, allowed trace
propagation, logs and agreed metrics as appropriate to this repository.
Separate unit tests, integration tests and deployment smoke tests. Avoid
brittle assertions on vendor internals. Do not alter product behavior. Run the
relevant test, lint, typecheck and build commands; report exact results and
stop.
```

**Checkpoint:** All relevant tests pass with observability credentials absent; no test contacts production telemetry services.

---

### Phase 13 — Production smoke-test procedure

**Objective:** Verify real deployment wiring without risking production data.

1. Confirm the expected release SHA is visible in deployment and Sentry.
2. Request the production health URL and confirm success.
3. Generate normal API traffic and confirm Sentry/Grafana telemetry arrives.
4. Trigger a controlled exception only in staging or through an authenticated, temporary diagnostic path that is removed afterward. Never add an unauthenticated public crash endpoint.
5. Make a browser API request and verify trace context and CORS behavior in browser developer tools.
6. Confirm the same request is discoverable in Render logs using request ID, and in Grafana using trace ID where the data is linked.
7. Confirm alerts are configured and notifications go to the intended email destination.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 13: Write docs/observability-smoke-test.md for the Wine Words app.

Document safe steps to verify startup, health checks, Sentry API and browser
events, source maps where applicable, OpenTelemetry/Grafana traces, CORS trace
propagation, Render logs, release identity, metrics and alerts. Do not include
steps that damage production data. Use staging for controlled exceptions; do
not create an unauthenticated production diagnostic endpoint. Include expected
results and troubleshooting steps. Do not deploy.
```

**Checkpoint:** Follow the written procedure in staging, then perform only safe read-only checks in production.

---

### Phase 14 — Documentation and operational runbook

**Objective:** Make the system maintainable without relying on this plan alone.

Create or update in each repository as appropriate:

- `docs/observability.md` — architecture, signal destinations, service identity and environment variables.
- `docs/observability-development.md` — local setup and local event checks.
- `docs/observability-production.md` — Render/front-end provider settings and deployment steps, without secret values.
- `docs/observability-troubleshooting.md` — missing Sentry events, missing symbols, no OTLP data, CORS/header issues, noisy alerts and exporter failure.
- `docs/observability-smoke-test.md` — procedure from Phase 13.

Explain which frontend variables are public (Sentry DSN/release/environment) and which values are private (Sentry source-map token, Grafana OTLP authorization, database/provider secrets). Never document actual credentials.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 14: Write or update Wine Words observability documentation for the
implementation that actually exists in this repository. Do not document
planned-but-unimplemented features as completed.

Cover architecture, Sentry, OpenTelemetry, Grafana Cloud, Render/Neon
monitoring, logging, metrics, traces, release tracking, environment variables,
secrets/privacy, development and production setup, tests, deployment,
troubleshooting, alert use and incident investigation. Never include real
credentials. Keep documentation synchronized with actual code and provider
configuration. Report files changed and stop.
```

**Checkpoint:** A reader can configure local development and investigate a production error from the docs without needing secret values in the repository.

---

### Phase 15 — Security and privacy audit

**Objective:** Ensure observability has not created a data leak or operational dependency.

Audit for:

- Credentials, API keys, passwords, JWTs, cookies, authorization headers and payment data.
- Personal data or wine/review/package content in events, logs, replays or spans.
- Grafana credentials or OTLP headers in browser bundles.
- Excessive session replay or source-map exposure.
- Trace propagation to third-party origins.
- High-cardinality labels and high-volume logs.
- Production debug logging.
- CORS changes broader than the verified frontend origins.
- Telemetry exporter failures that could crash or block Rails.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 15: Perform a read-only observability security and privacy audit of this
Wine Words repository and its documented deployment configuration.

Check Sentry, OpenTelemetry, Grafana, logs, metrics, source maps, Session Replay,
CORS, tracePropagationTargets, frontend bundles and telemetry failure behavior
for the risks listed in the plan. Do not print secret values. Return findings
with severity, affected file/configuration, evidence and a recommended fix.
Do not modify anything until I review the findings.
```

After reviewing findings, use a separate prompt to fix only approved observability issues, run relevant tests, and repeat the audit.

**Checkpoint:** No unresolved critical/high privacy or credential exposure findings; telemetry cannot take down the application.

---

### Phase 16 — Final project checkpoint

**Objective:** Confirm a coherent, working Wine Words observability baseline.

- [ ] API and frontend have separate Sentry projects.
- [ ] API and browser errors arrive in the correct environment.
- [ ] Errors include useful request/release context and no sensitive data.
- [ ] Front-end source maps resolve correctly if enabled.
- [ ] Render health checks and external uptime checks work.
- [ ] Neon and Render native dashboards are understood and reviewed.
- [ ] OpenTelemetry backend trace appears in Grafana if later phases were enabled.
- [ ] Browser-to-API context propagation was tested; no unsupported end-to-end claim remains.
- [ ] Structured logs and trace/request IDs correlate where supported.
- [ ] Product metrics have approved definitions and test coverage, if implemented.
- [ ] Dashboards and production alerts are reviewed and documented, if implemented.
- [ ] Release SHA is consistent across Sentry, OTel, logs and deployments.
- [ ] Automated tests pass without production credentials.
- [ ] Smoke-test and troubleshooting documentation matches actual implementation.
- [ ] Security/privacy audit is complete.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 16: Perform a read-only final observability checkpoint for Wine Words.
Compare the implementation, tests, deployment documentation and provider
configuration against the checklist in this plan. Mark each item complete,
partial, not implemented or blocked. Cite files or dashboard evidence where
available. Identify intentional limitations, unresolved risks and the next
smallest useful step. Do not modify files and do not proceed to BeachVolleyballHub.
```

## 7. Recommended execution order

1. Phase 0 audit both Wine Words repositories; keep findings separate.
2. Configure Sentry projects and environment variables.
3. Complete Sentry Rails integration and verify it.
4. Complete Sentry React integration and verify it.
5. Add release identity and source maps where supported.
6. Configure Render health checks, native dashboards and external uptime checks.
7. Review whether current monitoring answers the immediate operational questions.
8. Add OpenTelemetry traces, validate browser/API context propagation, then connect Grafana Cloud.
9. Add structured logs and agreed product metrics only where they add value.
10. Configure dashboards/alerts, tests, smoke-test docs and security audit.
11. Stop at every checkpoint and review results before starting the next phase.

## 8. References

### Project issues

- [Wine Words API issue #134 — Master Observability Implementation Plan](https://github.com/romalopes/wine_words_api/issues/134)
- [Wine Words API issue #138 — checkpoints, thresholds and safety refinements](https://github.com/romalopes/wine_words_api/issues/138)

### Attached guide

- `sentry_setup_ai_prompts_guide.md` — React + Rails Sentry setup and AI prompts (provided with this task).

### Official implementation references

- [Sentry for Rails](https://docs.sentry.io/platforms/ruby/guides/rails/)
- [Sentry Rails tracing](https://docs.sentry.io/platforms/ruby/guides/rails/tracing/)
- [Sentry for React](https://docs.sentry.io/platforms/javascript/guides/react/)
- [Sentry React tracing](https://docs.sentry.io/platforms/javascript/guides/react/tracing/)
- [OpenTelemetry Ruby getting started](https://opentelemetry.io/docs/languages/ruby/getting-started/)
- [OpenTelemetry Ruby instrumentation](https://opentelemetry.io/docs/languages/ruby/instrumentation/)
- [Render health checks](https://render.com/docs/health-checks)
- [Render logs](https://render.com/docs/logging)
- [Render service metrics](https://render.com/docs/service-metrics)
- [Neon monitoring](https://neon.tech/docs/introduction/monitoring)
- [Neon query history](https://neon.tech/docs/introduction/monitor-query-history)
- [Better Stack Render log/metrics integration](https://betterstack.com/docs/logs/render/) (optional, if centralizing Render telemetry is later justified)

## 9. Important implementation cautions

- Verify package versions and official vendor instructions at implementation time; do not copy code snippets blindly from the attached guide or issue text.
- Do not assume all Sentry/OpenTelemetry concepts use the same trace headers or share one trace backend. Demonstrate propagation with tests and actual dashboards.
- Keep browser trace targets narrow and CORS origins explicit.
- Keep the Grafana OTLP token, Sentry source-map token, database credentials, Cloudflare tokens and R2 credentials server-side or in CI/deployment secret stores.
- Avoid high-volume telemetry and keep initial thresholds adjustable. Use low-traffic-aware alert conditions to prevent noise.
- Observe, test and document each phase before beginning the next one.
