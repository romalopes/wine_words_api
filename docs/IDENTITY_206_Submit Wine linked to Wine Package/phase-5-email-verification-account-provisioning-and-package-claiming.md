# Phase 5 — Email Verification, Account Provisioning, and Package Claiming

## Status

Planned. No implementation started.

## Objective

Implement email verification for new submitters, secure account provisioning, password setup, existing-email privacy-preserving behavior, guest package access tokens, and package claiming. **Reference `WinePackage.submitter_id` (not `contact_snapshot_id`).**

## Dependencies

Phase 0, Phase 1, Phase 3

## Backend Work

### Backend Work

1. **Email Verification Flow (New Email)**
   - On submission with new email: send verification email with token
   - Token: cryptographically random, hashed at rest (bcrypt/argon2), 24h expiry, single-use
   - Verification endpoint: `POST /api/v1/trade/verify-email` with token
   - On success: create User (pending), send password setup email
   - Password setup endpoint: `POST /api/v1/trade/setup-password` with token + password
   - On success: activate User, link `submitter_id` to WinePackage, send confirmation

2. **Existing Email Behavior**
   - On submission with existing email: do NOT reveal account existence
   - Do NOT change credentials
   - Do NOT auto-login
   - Send "package submitted" email with secure claim link (different from verification)
   - Claim link contains package-scoped guest token

3. **Guest Package Access Tokens**
   - Generated at submission (Phase 3), stored hashed on `WinePackage.guest_token_hash`
   - Scope: single package
   - Permissions: view package, view items, send messages (Phase 9), view quotes/invoices (Phase 11)
   - Expiry: configurable (e.g., 30 days), revoked on package status change to completed/rejected
   - Redemption: `GET /api/v1/trade/packages/:token` returns package data
   - Token rotation on sensitive actions

4. **Package Claiming (Authenticated User)**
   - Authenticated user visits claim link or enters token
   - Verify token matches package
   - Link `package.submitter_id = current_user.id`
   - Revoke guest token
   - Add user to package notifications

5. **Account Switching Protections**
   - Logout clears all local data
   - No cross-user package access
   - Session invalidation on password change

6. **Rate Limiting (Phase 4 Integration)**
   - Verification resend rate limited
   - Token redemption rate limited
   - Password setup/resend rate limited
   - Guest access rate limited

## Frontend Work

### Frontend Work

1. **Email Verification Page**
   - Route: `/trade/verify-email/:token`
   - Shows verification status (success, expired, invalid, already verified)
   - On success: redirect to password setup

2. **Password Setup Page**
   - Route: `/trade/setup-password/:token`
   - Password requirements display
   - Strength meter
   - Confirm password field
   - On success: redirect to My Wine Packages

3. **Package Claim Page (Existing Email)**
   - Route: `/trade/claim/:token`
   - If unauthenticated: redirect to login with return_to
   - If authenticated: confirm claim, link package, redirect to My Wine Packages
   - No account existence disclosure

4. **Guest Package Access**
   - Route: `/trade/packages/:token` (from Phase 6)
   - Read-only package view (Phase 7 implements full view)
   - Link to claim/verify if not authenticated

5. **UX Considerations**
   - Clear messaging without revealing account existence
   - Token expiry handling with resend option
   - Rate limit messaging

## Database and Migration Work

### Database and Migration Work

1. **User Model Extensions**
   - Add `pending_verification` boolean or status field if not existing
   - Add `verification_token_hash`, `verification_token_expires_at`
   - Add `password_setup_token_hash`, `password_setup_token_expires_at`
   - Ensure existing authentication system supports these

2. **WinePackage Extensions**
   - `submitter_id` (already added in Phase 3)
   - `guest_token_hash`, `guest_token_expires_at`, `guest_token_revoked_at`

3. **Indexes**
   - Unique index on verification token hash
   - Unique index on password setup token hash
   - Index on guest_token_hash

## API and Authorization Requirements

- Reuse existing authentication and role policies
- Public endpoints narrowly scoped
- Object-level authorization for package access
- Editor/Admin explicit policies for assessment/commercial actions
- Internal notes staff-only
- Guest tokens: single package, scoped permissions, hashed, expiry, revocation
- No auto-login for existing accounts based on email submission

## Security Requirements

### Security Requirements

- Tokens: strong random, hashed at rest (bcrypt/argon2), single-use, expiry, revocation
- No account enumeration: same response for new/existing email
- No auto-login for existing accounts
- Guest tokens: package-scoped, hashed, expiry, revocation on status change
- Rate limiting on all token endpoints
- Secure password requirements
- Session invalidation on password setup
- Constant-time token comparison

## Testing Requirements

### Testing Requirements

1. **New Email Flow**
   - Verification email sent
   - Valid token creates pending user
   - Expired token rejected
   - Replayed token rejected
   - Invalid token rejected
   - Password setup works
   - User activated and linked to package via `submitter_id`

2. **Existing Email Flow**
   - No account existence disclosure
   - Claim link sent (not verification)
   - Claim link works for authenticated user
   - Claim link redirects unauthenticated to login
   - Package linked to user on claim via `submitter_id`

3. **Guest Token**
   - Valid token grants package access
   - Expired token rejected
   - Revoked token rejected
   - Wrong package token rejected
   - Token rotation works

4. **Security Tests**
   - Account enumeration attempts
   - Token brute force
   - Rate limit enforcement
   - Cross-user package access denied

## Deployment/Configuration Requirements

### Deployment/Configuration Requirements

- Email templates for verification, password setup, claim link
- Token expiry configuration
- Rate limit thresholds
- Existing mail infrastructure reused

## AI Implementation Prompt

```
Implement email verification, account provisioning, and package claiming for the Wine Words Trade portal.

Requirements:
- New email: verification → pending user → password setup → activation → package linking via submitter_id
- Existing email: no disclosure, claim link with guest token
- Guest tokens: hashed, 24h-30d expiry, package-scoped, revocable
- Package claiming links package to authenticated user via submitter_id
- No auto-login for existing accounts
- Rate limiting on all token endpoints
- Secure token handling (hashing, expiry, revocation, constant-time compare)

Key design points:
- submitter_id on WinePackage (added in Phase 3) is the link — NOT contact_snapshot_id
- Guest token stored on WinePackage (guest_token_hash, guest_token_expires_at, guest_token_revoked_at)
- No account enumeration: same API response for new/existing email
- Claim flow works for both: user clicks link while logged in, or user logs in then claims

Deliver:
- Verification, password setup, claim endpoints
- Token generation, hashing, validation services
- Email templates
- Frontend pages for verification, password setup, claim
- Guest package access page
- Model extensions for tokens
- Tests for all flows (new, existing, expired, replayed, revoked)
- Security tests (enumeration, brute force, rate limits)
```

## Acceptance Criteria

- [ ] New email: verification email sent, token works, password setup works, user activated, package linked via submitter_id
- [ ] Existing email: no account disclosure, claim link sent, claim works for authenticated user
- [ ] Guest tokens: generated at submission, hashed, expiry, revocation on status change
- [ ] Package claiming: links package to user via submitter_id, revokes guest token
- [ ] No auto-login for existing accounts
- [ ] Rate limiting on all token endpoints
- [ ] Account enumeration prevented
- [ ] All tests pass

## Exit Gate

- New and existing email flows do not disclose account existence or expose packages across users
- Guest tokens secure and tested
- Account provisioning integrated with existing User model via `submitter_id`

## Implementation Notes

- Reuse existing Wine Words authentication and email patterns
- Do not modify existing User authentication for current users
- Guest token is separate from API authentication tokens
- Claim flow must work for both: user clicks link while logged in, or user logs in then claims
- `submitter_id` (Phase 3) is the foreign key — no `contact_snapshot_id` reference needed

## Validation Results

*To be completed during execution*

- Commands executed:
- Tests run:
- Failures:
- Unresolved issues:
