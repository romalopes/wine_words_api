# Phase 7 — End-to-End Security, Integration, and Deployment

## Implemented security controls

- Admin/Editor creation authorization and role allowlists are enforced in a service, not only through strong parameters.
- Editors cannot create Admin/Editor accounts or manage invitations for privileged targets.
- Invitation tokens use 32 random bytes, are persisted only as SHA-256 digests, are filtered from Rails parameter logs, and are absent from management API responses/audit descriptions.
- Synchronous mail delivery avoids placing raw tokens in the current non-durable Active Job adapter.
- Public token validation and acceptance use POST endpoints with IP throttling.
- Acceptance locks invitation and user rows, rechecks status/email/lifecycle, consumes exactly once, and revokes competing usable invitations.
- Acceptance does not issue a JWT; users sign in through the existing session endpoint.

## Validation completed on October 27, 2026

- Feature-focused Rails suite: 47 examples passed before the invitation-email endpoint; the final backend feature suite and race test are run separately in the implementation validation output.
- Targeted RuboCop: clean for all changed Ruby implementation/spec files.
- Rails routes: creation, scoped invitation email, nested management routes, and public POST routes confirmed.
- Frontend focused component tests: create account, invitation management, public acceptance, and existing user detail pass.
- Frontend production build: passes.
- Frontend lint: no errors; only pre-existing warnings plus any explicitly reported current warning.
- `git diff --check`: passes in both repositories.

## Full-suite baseline findings

The Rails full suite has unrelated existing failures in older billing/log/wine/social-auth tests and fixtures (including newly required producer/country fields and readonly expectations). The frontend full suite has unrelated API-health/version-fixture failures; 451 tests passed in that run. These failures were not hidden or modified as part of the invitation feature.

## Deployment checklist

1. Validate the migration against a restored, sanitized production backup. This was not possible from the local repositories and remains required before production deployment.
2. Deploy the backward-compatible database migration before application code.
3. Configure and verify `FRONTEND_URL`, `MAIL_TRANSPORT`, provider credentials, `MAIL_FROM`, and `MAIL_REPLY_TO`.
4. Confirm the production frontend host serves `/accept-invitation` through SPA fallback on direct refresh.
5. Verify CORS permits the exact production frontend origin.
6. Run one controlled staging flow: create account, add email, send, validate, accept, sign in, resend invalidation, and revoke.
7. Monitor invitation issue/accept/failure audit events and provider errors without recording tokens.
8. Before moving delivery asynchronous, implement a durable encrypted queue or outbox; do not enqueue raw tokens in the current in-process adapter.

## Rollback

- Disable invitation issuance at the routing/feature level while preserving account and invitation rows.
- Keep the schema in place because it is backward compatible and preserves audit history.
- Do not run destructive seeds or delete unclaimed accounts as part of rollback.