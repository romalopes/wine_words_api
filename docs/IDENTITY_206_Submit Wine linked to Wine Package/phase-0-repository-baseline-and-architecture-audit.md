# Phase 0 — Repository Baseline and Architecture Audit

## Status

Planned. No code modifications have been made.

## Objective

Perform a read-only inspection of both Wine Words repositories to produce an architecture and reuse map before any implementation work begins. This phase must not modify files or generate migrations.

## Dependencies

None. This is the first phase.

## Scope

- Both repositories: `wine_words_api` (Rails API) and `wine_words` (React/Vite frontend)
- No code changes; documentation and analysis only

## Backend Work

### Repository Inspection

1. **WinePackage and WinePackageItem**
   - Models, associations, validations, status transitions
   - Existing creation workflows and controller actions
   - Serializers and API endpoints

2. **Core Domain Models**
   - Wine, Vintage, Review, Producer
   - ProducerMembership and role/permission policies

3. **Authentication and Account Management**
   - User authentication (JWT, sessions)
   - Email confirmation, password setup, password recovery
   - Role definitions (Guest, Reader, Reviewer, Editor, Admin)
4. **Notifications and Email**
   - Mailer patterns and delivery mechanisms
   - Existing notification types and templates
   - ActiveJob configuration for async delivery

5. **ActiveStorage and File Storage**
   - Current storage providers (local, S3, R2)
   - Attachment patterns and signed URL generation
   - Private vs public bucket configuration

6. **Billing and Payment**
   - Existing payment service code
   - Stripe or alternative provider integration status
   - Invoice generation and management

7. **API Conventions**
   - Routes structure (`config/routes.rb`)
   - Controller base classes and concerns
   - Serializer patterns (list vs detail)
   - Error response formats
   - Pagination envelope

8. **Security and Rate Limiting**
   - Existing rate-limiting middleware (Rack::Attack or similar)
   - Cloudflare configuration and WAF rules
   - Current security test coverage

9. **CI, Deployment, and Environment**
   - GitHub Actions or other CI configuration
   - Render/Kamal deployment configuration
   - Environment variable conventions
   - Database migration strategies

## Frontend Work

### Repository Inspection

1. **Routes and Navigation**
   - React Router configuration
   - Current header/menu structure
   - Responsive behavior

2. **API Client**
   - Base API service configuration
   - Authentication token handling
   - Error handling patterns

3. **Forms and UI Components**
   - Form validation libraries and patterns
   - Multi-step form implementations (if any)
   - Component library and styling approach

4. **State Management**
   - React Query / SWR / Redux usage
   - Local state patterns

5. **Testing**
   - Vitest component tests
   - Playwright E2E configuration (if present)
   - Test coverage patterns

6. **Build and Deployment**
   - Vite configuration
   - Environment variable handling (`VITE_*`)
   - Cloudflare Workers/Pages deployment

## Database and Migration Work

- Document current schema for all relevant tables
- Identify existing indexes, constraints, and foreign keys
- Note any pending or failed migrations
- Record current migration version

## API and Authorization Requirements

- Map existing authorization patterns (Pundit, custom policies, role checks)
- Document current API versioning strategy
- Identify public vs authenticated vs admin endpoints

## Security Requirements

- Current authentication flow vulnerabilities (if known)
- Rate limit coverage gaps
- File upload validation coverage
- PII handling in logs and error tracking

## Testing Requirements

- Run existing test suites to establish baseline
- Document current pass/fail status
- Identify test gaps against the Trade portal requirements

## Deployment/Configuration Requirements

- Document current environment variables in both repos
- Note any secrets management practices
- Identify shared infrastructure (Redis, database, storage)
## AI Implementation Prompt

```
You are working on Wine Words, consisting of:
- wine_words_api (Rails API)
- wine_words_frontend (React/Vite)

Perform a read-only architecture audit for the planned Trade portal and public wine submission workflow.

Inspect the actual repositories. Do not assume models, routes, gems, services or features exist based on this plan.

Specifically inspect:
1. WinePackage and WinePackageItem models, associations, validations, status transitions and existing creation workflows.
2. Wine, Vintage, Review and Producer models.
3. ProducerMembership and role/permission policies.
4. User authentication, email confirmation, password setup and password recovery.
5. Notifications and email delivery.
6. ActiveStorage and current storage providers.
7. Existing billing/payment code.
8. API routes, controllers, serializers and service conventions.
9. Frontend routes, navigation, API client, forms and UI components.
10. Existing rate limiting, Cloudflare configuration and security tests.
11. CI, deployment and environment-variable conventions.

Deliver:
- Existing architecture map.
- Reusable components.
- Required changes.
- Proposed migrations, only where necessary.
- API and frontend work breakdown.
- Security risks.
- Test gaps.
- Recommended implementation order.

Do not modify files or generate migrations in this phase.
Cite actual file paths and relevant code locations in the report.
```

## Acceptance Criteria

- [ ] Both repositories have been inspected
- [ ] Existing functionality and gaps are documented
- [ ] No duplicate domain model is proposed without justification
- [ ] Implementation dependencies are identified
- [ ] Architecture audit document is complete with file paths and code references

## Exit Gate

Proceed to Phase 1 only after:
- Architecture and reuse map is documented
- No code modifications have been made
- All gaps against the Trade portal plan are identified
- Recommended implementation order is validated

## Implementation Notes

- This phase is explicitly read-only
- Use `grep`, `find`, and file reading to inspect code
- Do not run generators, migrations, or modify any files
- Output should be a structured markdown document added to the docs folder

## Validation Results

### Audit findings (recorded 14 Nov — actual codebase inspection)

**Authentication & verification (heavily reusable):**
- Devise + devise-jwt (`authenticate_user!` in ApplicationController), Pundit (`ApplicationPolicy`), `Auditable`, `Api::Paginatable` concerns already wired.
- `users` already carries `email_verification_token_digest`, `email_verification_sent_at`, `email_verified_at` with `EmailVerificationService` (digest + single-use + expiry) and `Api::V1::EmailVerificationsController` (public GET verify endpoint). The Trade verification flow must **reuse** this service, not duplicate it.
- `enforce_email_verification!` is a global before_action — public trade endpoints must `skip_before_action` it where appropriate.

**WinePackage domain (as planned, with corrections):**
- `wine_packages.producer_id` is currently `null: false` → trade submissions require a migration to make it optional.
- `WinePackage#producer` association is not `optional:` → model change required.
- `WinePackageItem` already has `vintage_id`, `review_id`, `review_requested`, `proposed_wine_name`, `proposed_vintage_year` — snapshot fields extend this model.
- `WinePackageEvent` exists with `record!` factory, `visibility` (shared/internal), `idempotency_key`, `metadata` JSON — **no new event table**.
- Existing statuses/sources are string-backed enums in the model (`STATUSES`, `SOURCES`) — extension is additive.
- `WinePackageAuthorizable` concern + `WinePackagePolicy` define the admin/editor/producer-member tiers; trade adds a third actor (submitter/guest token).

**Shipping — deduplication correction to the plan:**
- The codebase already persists carrier tracking on `wine_packages` (`tracking_carrier/number/url/status/…`) with a `ShipmentTracking` singleton, `ShipmentTrackingEvent` history and a `shipment_trackings` controller. A new `wine_package_shipments` table would be duplication → Phase 12 **reuses** the existing tracking fields/events.

**Payments — deduplication correction to the plan:**
- Stripe is already integrated: `app/services/billing/*`, `Billing::Providers::Stripe.verify_webhook`, and `Api::V1::WebhooksController#stripe` dispatching via `BillingEvent.claim` (provider event idempotency). Trade invoices reuse this webhook endpoint, `BillingEvent.claim`, and the verification helper — **no new `stripe_webhook_events` table**.

**Rate limiting / abuse (separate plan):**
- `rack-attack` gem present with an initializer throttling analytics/invitations. Trade throttles follow the same file. Turnstile is NOT yet present — that is the separate infrastructure plan (`docs/TurnStile/`).

**Email:** existing mailers + `WinePackagesMailer` + notification records; `ActiveJob` in use.

**Frontend:** React SPA (`src/services/*Api.ts` factory pattern, `src/types/*`, `AppRoutes.tsx`); `packagesApi.ts` already speaks to the wine-package endpoints — trade API additions follow the same factory pattern.

**Test baseline:** RSpec (`spec/`), Playwright + Vitest on the frontend. Baseline suites are assumed green before Trade work starts (validated in Phase 14).

### Commands executed
- `grep`/`sed` inspection of `config/routes.rb`, `db/schema.rb`, `app/models/{wine_package,wine_package_item,wine_package_event,user}.rb`, controllers, concerns, policies, initializers, services trees, frontend `src/services`.

### Configuration identified (input to later phases)
- New env vars required: none for submission core; Stripe keys already configured for billing (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`); Turnstile keys pending the separate infrastructure plan.

### Unresolved issues
- None blocking Phase 1; the two plan corrections above (shipping table, webhook table) are recorded in Phase 1/11/12 documents.