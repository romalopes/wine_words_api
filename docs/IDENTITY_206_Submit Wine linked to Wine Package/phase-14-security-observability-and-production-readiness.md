# Phase 14 — Security, Observability, and Production Readiness

## Status

Planned. No implementation started.

## Objective

Complete security and operational checks before launch: full test suites, end-to-end scenarios, authorization tests, security tests, monitoring, dependency scans, PII review, Cloudflare/DNS/SSL review, rollback plan, and production smoke test.

## Dependencies

Phase 0, Phase 1, Phase 2, Phase 3, Phase 4, Phase 5, Phase 6, Phase 7, Phase 8, Phase 9, Phase 10, Phase 11, Phase 12, Phase 13

## Backend Work

### Backend Work

1. **Test Suite Execution**
   - Run the full RSpec suite (model, request, controller, integration, security)
   - Run performance/load checks where applicable
   - Record exact commands, pass/fail counts, and failures

2. **End-to-End Scenarios**
   - Anonymous submission → verification → claim → My Wine Packages
   - Existing-email submission → claim (no disclosure) → My Wine Packages
   - Full happy path: assess → partial approval → quote → invoice → Stripe payment → shipping release → receipt → review published
   - Guest-token lifecycle: access → rotate → revoke on terminal status
   - All denial paths (cross-user, cross-role, cross-package)

3. **Authorization Battery**
   - Object-level: user cannot access another submitter's package by ID
   - Role-level: Reader/Reviewer cannot reach admin trade endpoints; submitter cannot either
   - Guest token: single-package scope only; expired/revoked denied
   - Internal notes and internal events absent from every submitter/guest response
   - Producer matching never grants ProducerMembership

4. **Security Battery**
   - Turnstile: valid/invalid/expired/replayed/unavailable (fail-closed in production)
   - Rate limits: every public endpoint type; shared-IP (winery NAT) behaviour
   - Uploads: type, size, content-type verification; malware scan
   - XSS: message bodies and every user-input surface
   - Stripe webhook: signature, replay, idempotency
   - Email: retry, duplicate prevention, bounce handling
   - Enumeration: verification, claim, login paths return indistinguishable responses
   - Claim abuse: token brute force, replay, cross-package token use

5. **Dependency & Code Scans**
   - `bundler-audit`, `npm audit`, SAST (CodeQL/Brakeman — the repo already ships Brakeman config)

6. **Monitoring & Alerting**
   - Error tracking wired; performance monitoring
   - Business metrics: submissions, assessments, payments, shipping, review throughput
   - Alert thresholds for submission/email spikes

7. **PII & Secret Review**
   - Log sanitization (no emails, tokens, PII in error logs)
   - Secret scanning across both repos; environment-variable audit

8. **Infrastructure Review**
   - Cloudflare: production Turnstile widget, WAF rules, SSL/TLS
   - DNS records; R2/S3 bucket policies and CORS
   - Deployment configuration on each platform (frontend Worker vs Rails API — envs are separate)

## Frontend Work

### Frontend Work

1. **Test Suite Execution**
   - Vitest unit/component suites; Playwright E2E; accessibility audits — all recorded

2. **E2E Scenarios**
   - Full 4-step submission; verification/password/claim; My Wine Packages list + detail; conversation send/receive; quote accept → invoice → payment; shipping address entry; review progress; mobile + accessibility on every page

3. **Security Checks**
   - XSS in all user-input display; CSRF; Content-Security-Policy headers
   - No secrets in the built bundle (`VITE_*` audit); source maps not exposed in production

4. **Production Build Verification**
   - Build completes clean; CSP correct; Turnstile + Stripe keys present per environment

## Database and Migration Work

### Database and Migration Work

- Verify all migrations applied cleanly and are reversible
- Verify indexes exist and are used (query plans for hot paths)
- Verify DB-level constraints enforce business rules (unique invoice number, FKs)
- Backup/restore test

## API and Authorization Requirements

- All prior-phase authorization requirements re-verified as a suite
- Public endpoints enumerated and each one's rate limit + Turnstile requirement confirmed

## Security Requirements

### Security Requirements

- All prior-phase security requirements verified as one consolidated suite
- **No unresolved critical or high-severity findings** — this is the exit condition
- Penetration-test considerations documented (schedule if budget allows)
- Known limitations and accepted risks documented with mitigations

## Testing Requirements

### Testing Requirements

1. **Comprehensive Test Report**
   - Backend: model, request, integration, security suites — commands, counts, failures
   - Frontend: unit, component, E2E, accessibility — same
   - Coverage against targets; every critical path covered

2. **Production Smoke-Test Plan**
   - Post-deployment verification checklist (submit, assess, pay, ship, review)
   - Rollback triggers and procedure, documented and rehearsed

## Deployment/Configuration Requirements

### Deployment/Configuration Requirements

- Production environment variables set per platform; secrets in the secrets manager (not env files)
- Zero-downtime migration strategy; health checks configured
- Logging configured without PII; CDN/cache headers correct
- Rollback plan documented and tested

## AI Implementation Prompt

```
Perform a production-readiness and security review of the Wine Words Trade portal.

Review both repositories and the deployment configuration.

Test:
- Anonymous submission and Turnstile enforcement
- Existing/new email behaviour (no enumeration)
- Account claiming and package ownership (submitter_id semantics)
- Cross-user and cross-package access
- Internal note/event isolation (visibility: internal)
- Message and attachment security (XSS, signed URLs, private storage)
- Rate limits and abuse handling
- Package status transition permissions
- Partial approval and billing (quote -> invoice uniqueness)
- Invoice duplication prevention
- Payment webhook signature/replay/idempotency
- Shipping payment gate and Admin override audit
- Partial receipt and damage tracking
- Email retry/duplicate behaviour
- PII and secret leakage in logs and error tracking
- Existing Wine Words functionality regression (producer workflow, reviews, articles)

Run the complete test suites and relevant security/dependency scans
(bundler-audit, npm audit, Brakeman).

Deduplication constraints (from Phase 1):
- Verify the implementation actually REUSED WinePackageEvent (no parallel event store),
  JSONB contact_snapshot (no wine_submission_contacts table), and extended WinePackageItem
  (no parallel submission-item model) — flag any parallel systems that crept in
- Verify submitter_id and requested_by_id were kept distinct as designed

Produce:
- Findings ranked by severity
- Fixes for confirmed issues
- Remaining risks and mitigations
- Production deployment checklist
- Rollback plan
- Post-deployment smoke-test plan

Do not declare production-ready while critical/high-severity findings remain unresolved.
```

## Acceptance Criteria

- [ ] Full backend test suite passes
- [ ] Full frontend test suite passes
- [ ] E2E anonymous and authenticated scenarios pass
- [ ] Object-level authorization tests pass
- [ ] Account enumeration tests pass
- [ ] Claim-abuse tests pass
- [ ] Turnstile failure/replay tests pass
- [ ] Rate-limit tests pass
- [ ] Upload/XSS tests pass
- [ ] Webhook replay tests pass
- [ ] Email failure tests pass
- [ ] Dependency/security scans clean
- [ ] PII/secret leakage review clean
- [ ] Cloudflare/WAF/DNS/SSL reviewed
- [ ] Monitoring and alerts configured
- [ ] Rollback plan documented
- [ ] Production smoke-test plan documented
- [ ] No parallel systems introduced (deduplication audit clean)
- [ ] No unresolved critical/high-severity issues

## Exit Gate

- No unresolved critical/high security issues
- Existing Wine Words regression tests pass
- Monitoring and rollback steps documented
- Production configuration reviewed
- Ready for production deployment

## Implementation Notes

- This is the final gate before production release — do not skip or rush it
- All prior phases must be complete and tested
- Involve the security team if available; schedule a penetration test if budget allows
- Document known limitations and future improvements
- Confirm the Turnstile/rate-limiting separate infrastructure plan (docs/TurnStile/) is deployed before launch

## Validation Results

*To be completed during execution*

- Commands executed:
- Tests run:
- Failures:
- Unresolved issues:
