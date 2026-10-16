# Wine Words — OpenTelemetry + Sentry Observability Implementation Plan

**Target:** Wine Words Rails 8 API (Render), React/Vite/TypeScript frontend (Cloudflare Workers static assets), PostgreSQL (Neon/Supabase), Cloudflare R2.  
**Repositories:** [API](https://github.com/romalopes/wine_words_api) · [Frontend](https://github.com/romalopes/wine_words_frontend).  
**Status:** Implementation guide; verify repository state and current SDK APIs before making changes.

## 1. Goals and architectural decisions

- Capture backend and frontend exceptions in Sentry, with release/environment tags and safe request context.
- Instrument Rails HTTP requests, ActiveRecord queries, outbound HTTP, and background jobs with **OpenTelemetry** where supported.
- Connect frontend transactions to Rails requests with distributed trace propagation when compatible; verify actual linkage in Sentry rather than assuming it.
- Keep the option to export standard OTLP traces to Grafana Cloud/Tempo through a Collector later.
- Avoid double instrumentation, duplicate spans, personal-data leakage, expensive sampling, and application failures when telemetry is down.

### Important corrections to the starting proposal

1. `sentry-opentelemetry` integration and its initialization order/configuration are **version-dependent**. Do not assume `config.otlp.enabled` or `config.otlp.setup_otlp_traces_exporter` exist. Verify against the installed SDK's official docs and API before implementation.
2. Installing `opentelemetry-exporter-otlp` does **not** make Sentry an arbitrary OTLP endpoint. Sentry ingestion routes, support, authentication, and compatibility must be checked separately.
3. `@sentry/react` browser tracing is Sentry SDK instrumentation, **not** a substitute for the browser OpenTelemetry SDK or a guarantee of portable OTLP browser spans.
4. An OTel Collector does not automatically fan out telemetry. You must configure **receivers, processors, exporters, and pipelines** explicitly.
5. Sentry's tracing headers may include `sentry-trace` and `baggage`, whereas OTel typically propagates W3C `traceparent` and `tracestate`. Confirm interoperability using captured HTTP requests and actual linked traces.
6. `use_all` can enable more instrumentations than necessary; begin with a controlled set and measure overhead.

### Recommended staged architecture

```text
React/Vite (Cloudflare)
  ├─ Sentry browser SDK → Sentry: JS errors, browser transactions, optional replay
  └─ HTTP requests with allowed tracing headers → Rails API (Render)

Rails API
  ├─ Sentry Ruby/Rails → Sentry: errors and request context
  └─ OpenTelemetry SDK + selected instrumentations
       └─ configured trace exporter → OTLP Collector / supported backend
            ├─ Grafana Tempo / Grafana Cloud (optional phase)
            └─ other supported destination (only if explicitly configured)

Render / Neon / Cloudflare metrics and logs → provider dashboards initially
```

**V1 recommendation:** Sentry for frontend and backend error monitoring; Rails OTel traces exported to a standards-compliant endpoint only after validating interoperability. If the Sentry Ruby OTel bridge is compatible with the locked SDK versions, use it rather than running two competing Rails tracing pipelines. Do not configure both the Sentry tracer and OTel tracer to emit the same transactions without a documented deduplication strategy.

## 2. Phase 0 — Repository audit and baseline

### Command line — API

```bash
git clone https://github.com/romalopes/wine_words_api.git
cd wine_words_api
git checkout -b feature/observability-sentry-otel
ruby -v && bundle -v
bundle list | grep -Ei 'sentry|opentelemetry|rack|faraday' || true
rg -n 'Sentry|OpenTelemetry|OTEL_|SENTRY_|ActiveJob|Sidekiq|SolidQueue' . --glob '!vendor/**'
```

### Command line — frontend

```bash
git clone https://github.com/romalopes/wine_words_frontend.git
cd wine_words_frontend
git checkout -b feature/observability-sentry-otel
node -v && npm -v
npm ls @sentry/react @opentelemetry/api || true
rg -n 'Sentry|browserTracingIntegration|replayIntegration|fetch\(|axios|VITE_' src .env.example 2>/dev/null || true
```

Inspect: API Rails version, Rack/CORS middleware, deployment environment, background jobs, Sentry initializers, frontend entrypoint, React Router, API client, and existing observability code. Capture baseline request latency, memory, error rate, and deployment behavior.

**AI prompt 0 — audit (run separately in each repository):**

> Inspect this repository's current code and dependencies. Produce an observability audit covering existing Sentry/OTel integrations, Rails/React versions, API request clients, CORS, jobs, PII-sensitive endpoints, hosting variables, test setup, and risks of duplicate instrumentation. Do not edit files. Cite exact paths and suggest the smallest safe set of changes. Verify gem/npm APIs against installed versions; flag anything uncertain.

**Acceptance:** written audit, exact file inventory, baseline metrics, and decision on SDK ownership of backend tracing.

## 3. Phase 1 — Sentry projects, environments and secrets

Create **two Sentry projects**: `wine-words-api` (Ruby/Rails) and `wine-words-web` (React). Use separate DSNs for backend and frontend, and tag `development`, `staging`, and `production` appropriately. Set up alert ownership and retention controls. Consider separate projects for staging if needed.

### Render API environment variables

```dotenv
SENTRY_DSN=<server-side-DSN>
SENTRY_ENVIRONMENT=production
SENTRY_TRACES_SAMPLE_RATE=0.10
OTEL_SERVICE_NAME=wine-words-api
OTEL_RESOURCE_ATTRIBUTES=service.namespace=wine-words,deployment.environment.name=production
```

### Cloudflare frontend build variables

```dotenv
VITE_SENTRY_DSN=<browser-DSN>
VITE_APP_ENV=production
VITE_SENTRY_TRACES_SAMPLE_RATE=0.10
VITE_SENTRY_REPLAY_SAMPLE_RATE=0
VITE_SENTRY_REPLAY_ON_ERROR_SAMPLE_RATE=0.10
```

**Important:** `VITE_*` values are embedded into public browser bundles. A browser DSN is intended to be public, but **never** expose Sentry auth tokens, OTLP API tokens, Grafana credentials, or server secrets through `VITE_*`. Build-time variables must be configured in the actual Cloudflare deployment environment, not only in Render.

**AI prompt 1:**

> Add `.env.example` documentation for Wine Words observability without committing secrets. Respect the existing environment naming scheme. Identify exact Render and Cloudflare dashboard settings, distinguish browser-public values from server secrets, and document staging/production differences. Do not hardcode credentials.

## 4. Phase 2 — Rails Sentry error monitoring

### Command line

```bash
cd wine_words_api
bundle add sentry-ruby sentry-rails
bundle install
bundle exec ruby -e 'require "sentry-ruby"; puts Sentry::VERSION'
```

Create or update `config/initializers/sentry.rb` (merge with existing initializer, never duplicate):

```ruby
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
  config.send_default_pii = false
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.1").to_f
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
end
```

**Caution:** If phase 3 chooses OTel as the tracing owner, remove or adapt `traces_sample_rate` and configure the officially supported Sentry OTel bridge. The code above is a **baseline native-Sentry configuration**, not a final combined tracing configuration.

Set up request scrubbing for authorization headers, cookies, passwords, tokens, email addresses, and user-submitted article/review content. Keep environment and release tags. Use `before_send` only with explicit rules and tests; inspect SDK defaults first.

### Validation command line

```bash
RAILS_ENV=development bundle exec rails runner 'Sentry.capture_message("Wine Words API observability smoke test")'
bundle exec rails test
```

Only send the smoke test to a configured test Sentry project; never test by leaking real credentials or personal data.

**AI prompt 2:**

> Integrate the current stable `sentry-ruby` and `sentry-rails` APIs into this Rails app, reusing any existing initializer. Include environment, release, safe error context, privacy filters, and disabled/low-noise local development. Add tests and document a safe smoke test. Do not enable OTel tracing yet. Show all changed files and commands.

## 5. Phase 3 — Rails OpenTelemetry tracing and Sentry interoperability

### Choose one implementation path

**Path A — Sentry + OTel bridge (preferred only if verified):** Check the current `sentry-opentelemetry` gem documentation, supported `sentry-ruby` version, initialization order, and exporter semantics. If supported, use its documented integration to associate Sentry errors with OTel spans. Do **not** copy undocumented `config.otlp.*` calls.

**Path B — Independent OTel export:** Keep Sentry for errors; export Rails traces to an OTLP-compatible Collector/Grafana endpoint. Correlation to Sentry issues may be partial until propagation and cross-tool trace IDs are proven. This path has the clearest standards-based future portability.

### Command line

```bash
cd wine_words_api
bundle add opentelemetry-sdk opentelemetry-exporter-otlp \
  opentelemetry-instrumentation-rack \
  opentelemetry-instrumentation-active_record \
  opentelemetry-instrumentation-net_http
# Only after verifying current compatibility:
# bundle add sentry-opentelemetry
bundle install
bundle exec ruby -e 'require "opentelemetry/sdk"; puts "OTel SDK loaded"'
```

**Illustrative OTel initializer** (for independent exporter path; adapt exact instrumentation identifiers to installed versions):

```ruby
# config/initializers/opentelemetry.rb
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/rack"
require "opentelemetry/instrumentation/active_record"
require "opentelemetry/instrumentation/net/http"

if ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].present?
  OpenTelemetry::SDK.configure do |config|
    config.service_name = ENV.fetch("OTEL_SERVICE_NAME", "wine-words-api")
    config.use "OpenTelemetry::Instrumentation::Rack"
    config.use "OpenTelemetry::Instrumentation::ActiveRecord"
    config.use "OpenTelemetry::Instrumentation::Net::HTTP"
  end
end
```

Exporter configuration varies with gem versions. Confirm the installed SDK actually configures a trace exporter (rather than silently defaulting to console/no-op) and that endpoint, authentication, TLS, timeout, batching, and sampling are correct. Avoid enabling `use_all` before checking all included instrumentations. Add Solid Queue/ActiveJob instrumentation only after compatibility checks.

### OTLP variables (backend only)

```dotenv
OTEL_EXPORTER_OTLP_ENDPOINT=https://<collector-host>:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=0.10
OTEL_EXPORTER_OTLP_HEADERS=<secure-auth-headers-if-needed>
```

**Note:** The exact URL path (e.g. `/v1/traces` versus `/otlp`) depends on the receiver and exporter configuration. Never assume all providers use the same endpoint path or auth header syntax. Check whether the Ruby OTLP exporter reads these env vars automatically in the installed version.

### Validation

```bash
bundle exec rails runner 'puts OpenTelemetry.tracer_provider.class'
bundle exec rails test
# Start the API locally, then issue a request to an existing non-sensitive endpoint:
curl -i http://localhost:3000/up
```

Verify in the chosen telemetry backend: root HTTP span, DB child span, outbound HTTP child span, correct `service.name`, environment, status, and no SQL bind values/PII. Inspect duplicate spans and memory usage.

**AI prompt 3:**

> Implement Rails OpenTelemetry instrumentation for Rack, ActiveRecord, and Net::HTTP using the versions actually installed. Compare the current documented `sentry-opentelemetry` bridge with independent OTLP export, choose the safest compatible path, and explain the tradeoff. Do not use undocumented Sentry `config.otlp` methods. Ensure one tracing owner, parent-based sampling, secure resource attributes, privacy filtering, exporter failure isolation, and tests. Provide a deployment rollback switch.

## 6. Phase 4 — React/Vite Sentry

### Command line

```bash
cd wine_words_frontend
npm install @sentry/react
npm ls @sentry/react
```

Extract initialization to `src/observability/sentry.ts` or reuse the existing Sentry setup:

```typescript
import * as Sentry from "@sentry/react";

const dsn = import.meta.env.VITE_SENTRY_DSN;
const apiOrigin = import.meta.env.VITE_API_BASE_URL;

if (dsn) {
  Sentry.init({
    dsn,
    environment: import.meta.env.VITE_APP_ENV || import.meta.env.MODE,
    integrations: [
      Sentry.browserTracingIntegration(),
      // Add Sentry.replayIntegration() only after privacy review.
    ],
    tracesSampleRate: Number(import.meta.env.VITE_SENTRY_TRACES_SAMPLE_RATE ?? 0.1),
    tracePropagationTargets: [
      /^https?:\/\/localhost(?::\d+)?(?:\/|$)/,
      ...(apiOrigin ? [apiOrigin] : []),
    ],
    sendDefaultPii: false,
  });
}
```

**Review required:** `tracePropagationTargets` matches request URLs according to the installed SDK version. Use a properly escaped, anchored API-origin matcher rather than a broad string if there are multiple similarly named hosts. Confirm the actual Vite variable name (`VITE_API_BASE_URL` is an example). If the app already initializes Sentry in `main.tsx`, move that configuration rather than initializing twice. Preserve the existing error boundary and fallback UI.

In `src/main.tsx`, import the initializer **before** application/network modules:

```typescript
import "./observability/sentry";
```

If React Router is used, consider Sentry's router integration supported by the installed router/SDK versions. Configure release IDs and source maps only with a secure CI build token.

### Command line validation

```bash
npm run build
npm run lint
npm test -- --run   # only if the project uses Vitest with this command
```

**AI prompt 4:**

> Review the current Wine Words frontend `main.tsx`, existing Sentry initialization, error boundary, routing, and API client. Implement a single Sentry initialization compatible with the installed SDK; preserve existing behavior. Add precise trace propagation to the actual Rails API origins, sensible production sampling, disabled-by-default replay, environment/release tags, and tests. Never place auth tokens in Vite variables. Show exact changed files.

## 7. Phase 5 — CORS, trace context and distributed tracing

Current domain architecture may include:

- Frontend: `https://wine-words.romalopes.workers.dev` or `https://wine-words.beachvolleyballhub.com`
- API: `https://wine-words-api.onrender.com` or `https://api.wine-words.beachvolleyballhub.com`
- Development: Vite localhost and Rails localhost.

These are **examples to verify against live deployment**; do not assume all are active.

For cross-origin requests, update the existing `rack-cors` configuration to allow only trusted frontend origins, appropriate methods, and explicitly required request headers, potentially including `sentry-trace`, `baggage`, `traceparent`, and `tracestate`. The browser's preflight request must be accepted. If using credentialed requests, never use wildcard origins.

```ruby
# Example fragment only — merge into existing cors.rb configuration:
headers: %w[Authorization Content-Type Accept Sentry-Trace Baggage Traceparent Tracestate]
```

Test the real preflight:

```bash
curl -i -X OPTIONS 'https://wine-words-api.onrender.com/<real-api-path>' \
  -H 'Origin: https://wine-words.romalopes.workers.dev' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: sentry-trace,baggage,traceparent,tracestate'
```

Inspect Network tab: emitted headers, allowed origins, no unexpected preflight failures, and whether frontend and backend spans truly share a trace in Sentry or Grafana. **Header presence alone does not prove linked tracing.** Browser-to-OTel trace linkage may require a documented propagation bridge; if absent, document separate frontend and backend traces instead of claiming seamless linking.

**AI prompt 5:**

> Update Wine Words Rails CORS and frontend tracing propagation for the project's verified active origins. Keep strict origin allowlists, support the trace headers actually emitted by the selected Sentry/OTel SDKs, and maintain existing authentication behavior. Add request/preflight tests and an end-to-end trace verification procedure. If the two SDKs cannot propagate a shared trace ID, report that limitation and propose a supported bridge without inventing one.

## 8. Phase 6 — Privacy, replay, releases and alerts

- Keep `send_default_pii` / `sendDefaultPii` disabled unless explicitly justified.
- Scrub Authorization, Cookie, Set-Cookie, session IDs, passwords, reset tokens, email addresses, and submitted wine reviews/articles.
- If enabling Sentry Replay, review mask/block settings for all forms, editor content, auth pages, and user profiles. Begin with **0% regular replay** and low error replay sampling.
- Use source maps via CI with a **server-side** `SENTRY_AUTH_TOKEN`, scoped to the frontend Sentry project. Do not upload secrets or publish private source maps unnecessarily.
- Set stable release names, ideally a Git SHA shared with deployment metadata.
- Create alerts for backend 5xx exceptions, frontend crash spikes, recurring 502/503s, high latency, and deployment regressions.
- Remember Sentry does not replace Render instance-memory monitoring, uptime checks, or PostgreSQL database metrics.

### Optional CLI source map workflow

```bash
cd wine_words_frontend
npm install --save-dev @sentry/cli
# Prefer official Sentry Vite plugin if supported by this project's build.
# Store SENTRY_AUTH_TOKEN in CI/Cloudflare secrets, never in VITE_*.
```

**AI prompt 6:**

> Add production-safe Sentry data scrubbing, explicit session replay privacy rules (disabled by default), source-map release handling via CI secrets, and alerting documentation. Audit Wine Words login, password reset, editor forms, wine reviews, comments, and user profile flows for PII exposure. Include tests proving sensitive values are not transmitted.

## 9. Phase 7 — Optional Grafana Cloud / Collector

Do this **after** Sentry error monitoring and OTel traces are stable. Prefer server-to-server export from Rails or an OTel Collector; do not expose Grafana API tokens in React.

### Collector concept (example only; replace endpoints/credentials)

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
processors:
  batch: {}
  memory_limiter:
    check_interval: 5s
    limit_mib: 256
exporters:
  otlphttp/grafana:
    endpoint: ${env:GRAFANA_OTLP_ENDPOINT}
    headers:
      Authorization: ${env:GRAFANA_AUTH_HEADER}
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlphttp/grafana]
```

The Collector configuration above sends **traces only to Grafana**. A Sentry exporter is deliberately not shown: add a second destination only if Sentry currently documents a compatible authenticated OTLP ingestion endpoint/exporter for this use case. If not, continue Sentry's native SDK for errors and browser tracing. Logs and metrics need **separate pipelines and supported exporters**.

### Command line (if using a local Collector)

```bash
# Save validated configuration as otel-collector.yaml.
docker run --rm -p 4317:4317 -p 4318:4318 \
  -v "$PWD/otel-collector.yaml:/etc/otelcol-contrib/config.yaml:ro" \
  -e GRAFANA_OTLP_ENDPOINT -e GRAFANA_AUTH_HEADER \
  otel/opentelemetry-collector-contrib:<pin-tested-version> \
  --config=/etc/otelcol-contrib/config.yaml
```

**Security:** Do not publicly expose an unauthenticated Collector receiver. In production, use managed OTLP ingress or a private/authenticated collector. Pin a tested image version and restrict network access. Verify provider-specific path, headers, and authentication format.

**AI prompt 7:**

> Design an optional OTLP Collector deployment for Wine Words on a low-cost managed platform. Compare direct Rails-to-Grafana Cloud export with a Collector. Supply a version-pinned, validated Collector config with authentication, TLS, memory limits, batch/retry behavior, private ingress, and cost controls. Never assume Sentry accepts arbitrary OTLP traces; document any verified integration separately. Include Terraform/Docker only if justified by the existing infrastructure.

## 10. Phase 8 — Testing and deployment

### Test matrix

| Scenario | Expected outcome |
|---|---|
| Frontend deliberate test error | Appears in `wine-words-web` Sentry project, correct release/environment |
| Backend deliberate test error | Appears in `wine-words-api` Sentry project without sensitive headers |
| Normal API request | Trace visible in selected backend with Rails and DB spans |
| Frontend → API request | CORS succeeds; verify actual trace linkage, or document gap |
| Background job | Errors captured; job spans only if supported/instrumented |
| OTLP destination unavailable | API remains responsive; telemetry failures are bounded |
| Deploy without Sentry DSN | App boots; no monitoring crashes |
| Auth/editor/review requests | No tokens or sensitive form content in events/spans/replays |
| 100 requests at sampling target | Span volume and overhead within acceptable bounds |
| Rollback | Disable exporters/replay or revert deploy without breaking app |

### Commands before merge

```bash
# API
bundle exec rubocop
bundle exec rails test
bundle exec rails zeitwerk:check

# Frontend
npm run lint
npm run build
# Execute project's actual test command if defined in package.json.
```

Open two separate PRs, backend first. Deploy staging first, validate errors and traces, then production with low sampling. Monitor Render memory/CPU, response latency, telemetry network traffic, Sentry quotas, and alert noise for 24–48 hours. Increase sampling only when justified.

### Rollback plan

1. Set `SENTRY_TRACES_SAMPLE_RATE=0` and `VITE_SENTRY_TRACES_SAMPLE_RATE=0` (frontend requires rebuild/redeploy).
2. Set OTLP export off using the initializer's explicit environment guard, and redeploy API.
3. Disable replay via configuration/build variables and redeploy frontend.
4. If failures persist, roll back the last Render deployment and Cloudflare deployment independently.
5. Preserve error monitoring if safe; disable only the component causing the incident.

**AI prompt 8:**

> Implement and run an observability acceptance checklist for this repository. Add automated tests for initializer safety, PII scrubbing, CORS preflight, propagation headers, exporter outage handling, and duplicate span prevention. Provide exact commands, expected results, manual Sentry/Grafana checks, rollout order, and rollback steps. Do not claim distributed trace correlation unless observed in the telemetry UI.

## 11. Phase 9 — Documentation and maintenance

Create `docs/observability/README.md` in each repository, containing: architecture, installed versions, dashboard links, secret names (not values), environment matrix, source-map setup, sample rates, privacy decisions, test commands, incident runbook, alert owners, and rollback instructions. Add an observability review to dependency upgrades.

**AI prompt 9:**

> Generate `docs/observability/README.md` for this repository based only on the implementation that actually exists. Include architecture, exact files changed, commands for local/staging/production, Render or Cloudflare environment settings, troubleshooting, privacy and retention, smoke tests, and rollback. Do not document features as implemented unless code and tests verify them.

## 12. Recommended rollout sequence

| Order | Milestone | Priority | Done when |
|---|---|---|---|
| 1 | Audit both repos | Critical | Existing instrumentation and hosting verified |
| 2 | Sentry projects/secrets | Critical | Correct DSNs and environments |
| 3 | Rails Sentry errors | Critical | Test event visible and sanitized |
| 4 | React Sentry errors/tracing | Critical | Frontend error and route/request telemetry visible |
| 5 | Rails OTel instrumentation | High | Exported spans and overhead verified |
| 6 | CORS and trace propagation | High | No preflight regressions; correlation status documented |
| 7 | Privacy, source maps, alerts | High | Sensitive-data tests and alerts pass |
| 8 | Grafana/Collector | Optional | Standards-based export demonstrated |
| 9 | Runbooks and rollout | High | Staging validated, production monitored |

## 13. Definition of done

- Both Wine Words applications report actionable errors to separate Sentry projects.
- Rails traces have consistent `service.name`, environment, release, HTTP, DB, and outgoing request spans where supported.
- Frontend requests do not break due to trace propagation or CORS.
- Cross-service trace linkage is either demonstrably working or explicitly documented as a limitation.
- No auth tokens, session cookies, sensitive user content, or private API credentials leak into telemetry.
- Production sampling, source maps, alerts, and quota limits are documented.
- A failed telemetry endpoint does not bring down Wine Words.
- Every changed repository has tests, deployment instructions, and rollback steps.

## References to verify before implementation

- [Sentry Ruby SDK](https://docs.sentry.io/platforms/ruby/)
- [Sentry JavaScript / React SDK](https://docs.sentry.io/platforms/javascript/guides/react/)
- [OpenTelemetry Ruby](https://opentelemetry.io/docs/languages/ruby/)
- [OpenTelemetry Collector configuration](https://opentelemetry.io/docs/collector/configuration/)
- [Grafana Cloud OTLP ingestion](https://grafana.com/docs/grafana-cloud/send-data/otlp/send-data-otlp/)
- [Render environment variables](https://render.com/docs/configure-environment-variables)
- [Cloudflare Workers environment variables and secrets](https://developers.cloudflare.com/workers/configuration/environment-variables/)

**Final note:** This is an implementation plan, not a claim that either repository has been modified or that any version-specific SDK method has been verified against the current live code.
