# Phase 2 — Privileged Account Creation API

Implemented `POST /api/v1/users` for authenticated Admin and Editor actors.

## Contract

- Creates `unclaimed` users without passwords.
- Requires first and last name; email is optional.
- Admin may assign Editor, Reviewer, Reader, or Guest. Admin assignment is rejected.
- Editor may assign only Reviewer or Reader.
- Unknown or client-supplied lifecycle/password/privilege fields are ignored.
- Optional producer memberships are transactionally created with a server-derived actor.
- Returns the standard user-detail payload including account and invitation state.

Public registration remains unchanged.