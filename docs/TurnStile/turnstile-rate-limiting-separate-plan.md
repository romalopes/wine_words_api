# Phase 4 (Separate) - Cloudflare Turnstile, Rate Limiting, and Abuse Protection

## Status

**Separate Infrastructure Plan** - Not part of Wine Submission/Package workflow. This phase covers cross-cutting security infrastructure that applies to all public endpoints across the Wine Words platform.

## Context

Originally planned as Phase 4 in the Wine Trade Portal implementation. Removed because Turnstile, rate limiting, and abuse protection are **platform-wide infrastructure concerns**, not specific to the wine submission feature. They should be implemented once at the platform level and reused by all public endpoints (including but not limited to Trade submissions).

## Scope

This plan covers:
- Cloudflare Turnstile integration (widget + server-side verification)
- Comprehensive rate limiting (per-endpoint, shared Redis store)
- Anti-abuse controls (body size limits, honeypot, WAF rules)
- Platform-wide deployment configuration

## Dependencies

- Platform infrastructure (Cloudflare, Redis, Rails API, Frontend Workers)
- Existing authentication system
- Existing deployment pipelines

## Backend Work

### 1. Cloudflare Turnstile Integration
- Server-side Siteverify on all protected public endpoints
- Validate: success, hostname, action, cdata
- Handle timeout, network failure, malformed response (fail closed in production)
- Token replay protection: store used tokens (hashed) with short TTL, reject duplicates
- Do not log secret or token
- Configurable: site key (frontend), secret key (backend), expected hostnames, enabled flag

### 2. Rate Limiting
- Use existing Rails rate-limiting solution or Rack::Attack
- Shared store (Redis) for multi-instance deployment
- Separate limits per endpoint type (configurable via admin UI):
  - Public form submissions
  - Auth endpoints (login, register, password reset)
  - API endpoints
  - File uploads
- Rate limit by: IP + normalized email/contact + relevant resource
- Careful with shared winery/NAT IPs
- Low initial burst, reasonable rolling window, progressive cooldown
- Generic 429 responses (no account enumeration)
- Retry-After header

### 3. Additional Anti-Abuse Controls
- Request body size limits (Rails, proxy, edge)
- Upload size limits
- Strict parameter allowlists
- Honeypot field (supplemental detection)
- Submission idempotency
- Email verification before sensitive actions
- Attachment type/size validation
- Safe error handling (no stack traces)
- Monitoring for submission/email spikes
- Admin ability to flag/disable abusive contacts or resources
- Cloudflare WAF rules for obvious malicious traffic
- Do not block legitimate users solely because their IP is shared or geolocation is unusual

### 4. Configuration
- Environment variables: TURNSTILE_SECRET_KEY, TURNSTILE_EXPECTED_HOSTNAMES, TURNSTILE_ENABLED
- Rate limit thresholds tunable via env/config/admin UI
- Feature flag for Turnstile (disable in development if needed)

## Frontend Work

### 1. Turnstile Widget Integration
- Add Turnstile script to layout
- Reusable Turnstile component for any form
- Handle: token callback, expiry callback, error callback
- Pass token with submission request
- Configurable site key via VITE_TURNSTILE_SITE_KEY
- Staging vs production widget keys

### 2. Rate Limit UX
- Handle 429 responses gracefully
- Show retry guidance
- Disable submit button during cooldown

## Database and Migration Work

1. **Rate Limit Storage**
   - Redis (shared) for rate limit counters
   - No schema migrations if using Redis
   - If using database-backed rate limiting: migration for rate_limit_buckets table

2. **Turnstile Token Replay Storage**
   - Redis set with TTL (or database table with expiry)
   - Store hashed tokens

## API and Authorization Requirements

- Platform-wide middleware (not feature-specific)
- Applied at route level via middleware/concerns
- No feature-specific authorization logic

## Security Requirements

- Turnstile secret only in backend environment
- Fail closed when Turnstile unavailable in production
- Token single-use enforcement
- Rate limit storage shared across instances
- Generic error responses (no enumeration)
- No logging of secrets or tokens
- Request/body size limits at all layers

## Testing Requirements

1. **Turnstile Tests**
   - Valid token passes
   - Invalid token rejected
   - Expired token rejected
   - Replayed token rejected
   - Unavailable service: fail closed (production), configurable (staging)
   - Wrong hostname rejected
   - Wrong action rejected

2. **Rate Limit Tests**
   - Each endpoint type has separate limit
   - Burst allowance respected
   - Rolling window enforced
   - Cooldown progression
   - 429 response format
   - Shared IP handling (winery NAT)
   - Keyed by IP + email + resource

3. **Anti-Abuse Tests**
   - Oversized request rejected
   - Oversized upload rejected
   - Parameter allowlist enforced
   - Honeypot detection works
   - Idempotency prevents duplicate submissions
   - Email verification required for sensitive actions
   - Attachment validation works
   - Error responses don't leak info
   - Admin flag/disable works

## Deployment/Configuration Requirements

### 1. Cloudflare Configuration
- Production Turnstile widget created
- Staging widget (separate) if staging used
- Correct hostnames configured
- Site key in frontend env (VITE_TURNSTILE_SITE_KEY)
- Secret key in Rails deployment secrets
- WAF/rate-limit rules configured
- SSL/TLS and HTTPS enforced
- R2 bucket/CORS if used for file storage

### 2. Environment Variables
- Frontend: VITE_TURNSTILE_SITE_KEY
- Backend: TURNSTILE_SECRET_KEY, TURNSTILE_EXPECTED_HOSTNAMES, TURNSTILE_ENABLED
- Rate limit thresholds via config/env
- Redis connection for rate limit store

### 3. Deployment Platforms
- Frontend Worker/Pages: site key configured
- Rails API: secret key, Redis, rate limit config
- Separate env values per platform

## AI Implementation Prompt



## Acceptance Criteria

- [ ] Turnstile verification works server-side as reusable service
- [ ] Valid tokens pass, invalid/expired/replayed rejected
- [ ] Fail closed behavior in production
- [ ] Separate rate limits for each public endpoint type (configurable)
- [ ] Rate limits use shared Redis store
- [ ] 429 responses are generic with Retry-After
- [ ] Request/body size limits enforced at all layers
- [ ] Honeypot detection works
- [ ] Admin can flag/disable abusive actors
- [ ] Cloudflare WAF rules configured
- [ ] Frontend widget renders and provides token (reusable component)
- [ ] All Turnstile tests pass
- [ ] All rate limit tests pass
- [ ] All anti-abuse tests pass
- [ ] Documentation for feature team integration complete

## Exit Gate

- Turnstile, rate limiting, and abuse protection implemented as platform infrastructure
- Not tied to any specific feature
- Feature teams can integrate by adding middleware/concern to their routes
- Configuration documented for staging/production
- All tests pass

## Implementation Notes

- Turnstile is one layer, not a substitute for rate limiting or validation
- Tune rate limit thresholds using logs/metrics
- Ensure rate limit storage works across multiple Rails instances
- Do not assume frontend Worker and Rails API share environment variables
- Configure each platform separately
- This infrastructure should be in place BEFORE any public feature launches
- Wine Trade Portal (Phases 0-14) will integrate this by adding the Turnstile/rate-limit concerns to their routes

## Validation Results

*To be completed during execution*

- Commands executed:
- Tests run:
- Failures:
- Unresolved issues:
