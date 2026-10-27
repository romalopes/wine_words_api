# Phase 5 — Admin/Editor Account Management Frontend

The React `/users` screen now includes a privileged account-creation form with role options filtered by actor privilege. Successful creation opens the existing user detail workflow.

The `/users/:id` screen now includes invitation email editing, send/resend/revoke controls, delivery metadata, and preserved invitation history. Raw invitation tokens are never returned to or stored by this interface.