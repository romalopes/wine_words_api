# Phase 4 — Public Invitation Validation and Acceptance API

Implemented public POST endpoints:

- `POST /api/v1/invitations/validate`
- `POST /api/v1/invitations/accept`

Validation returns only a masked email, display name, and expiry. Acceptance locks both invitation and user rows, rechecks lifecycle/email/token state, sets the password, activates the user, consumes the invitation, and revokes competing invitations.

## Session decision

Acceptance does **not** automatically issue a JWT. The response directs the user to sign in through the existing authentication endpoint. This keeps the public invitation controller from becoming a second session-issuance implementation and reduces token/session coupling.