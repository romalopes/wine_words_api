# Phase 3 — Invitation Management and Delivery

Implemented authenticated nested routes for invitation history, send/resend, and revoke.

## Security and delivery decisions

- Only Admin and Editor actors may manage invitations.
- Tokens contain 32 random bytes; only SHA-256 digests are persisted.
- Raw tokens are passed directly to synchronous Action Mailer delivery and are never API response fields or audit text.
- Acceptance links use a URL fragment (`#token=...`), so the raw token is not sent in ordinary frontend/CDN page requests.
- Synchronous delivery avoids persisting raw token arguments in the current non-durable Active Job adapter.
- Sending is limited to eligible unclaimed, non-deleted accounts with a valid email.
- A one-minute per-account cooldown applies; public routes also have IP throttles.
- Resend revokes every previously usable invitation while preserving its audit row.
- Provider acceptance is recorded as `delivery_status=accepted`; it is not described as mailbox delivery.

Before relying on invitations at high volume, deploy a durable encrypted queue or outbox and delivery reconciliation.