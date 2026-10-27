# Phase 6 — Public Invitation Acceptance Frontend

Added `/accept-invitation#token=...` to the React SPA. The fragment keeps the token out of ordinary frontend server/CDN request logs.

The page validates the token with a POST request, displays only masked account context, collects and confirms a password, activates the account, and links to the normal sign-in page. It handles missing, invalid, expired, revoked, replayed, and server-rejected invitations without exposing whether another account exists.