# Email identity and account names

Email is the unique user-facing login identifier. `users.user_name` and its unique index have been removed. First and last names are stored only in `accounts`, are not unique, and support Unicode, spaces, and punctuation. Password authentication and social identities retain their existing behavior.

## Registration and profiles

React signup and the Rails signup page collect required **First name** and **Last name**, each up to 80 characters. The API accepts:

```json
{
  "user": {
    "first_name": "Élodie",
    "last_name": "O’Connor",
    "email": "elodie@example.com",
    "password": "example-password",
    "password_confirmation": "example-password"
  }
}
```

User and Account are saved atomically. Every user created through the model gets one persisted Account, including social signups and programmatic creation. The existing unique `accounts.user_id` index prevents multiple accounts for a user. Updating personal information edits that account; it no longer changes a username. Both names are required when saving the profile form or updating it through the profile API.

Social signup copies an available provider name into Account (first word as first name, remainder as last name). Providers can omit names; those users still get an Account and can complete it in Account settings. Returning or newly linked social providers preserve existing profile information.

Session, registration, password-reset, impersonation, and user-directory responses expose `display_name`, `first_name`, and `last_name`. `display_name` combines account names and falls back to email when no name is known. Other user references (logs and verification results) expose a display name where appropriate. JWTs no longer include a username claim. The frontend header, bylines, review author labels, admin user search, mailers, and Stripe customer creation use account-backed names.

Search matches account first/last/full names or email. Account name changes enqueue reindexing for that user's articles and reviews.

## Existing users and deployment

Migration: `20261006000001_move_user_names_to_accounts.rb`.

1. Create missing accounts for existing users.
2. Preserve profiles that already have either first or last name.
3. For profiles with neither name, split the old username at its first whitespace: the first part becomes first name and the remainder becomes last name. Blank handles produce blank names; one-word handles have no last name. This preserves available legacy labels, not verified real names.
4. Drop the username column and its unique index.

Unknown names are deliberately left blank. Users with incomplete or handle-based names should complete/correct Account settings. No names are inferred from email addresses.

Deploy the API and frontend together: the signup request and user-response field names have changed. Stop old application/worker processes before the migration and restart them with the updated code afterward so stale schema caches and username references are not used.

```sh
bin/rails db:migrate
bin/rails search:reindex
```

Take the normal database backup before deploying a destructive schema migration. This migration is marked irreversible: original unique handles cannot be reconstructed from editable, non-unique account names. Rollback requires restoring the pre-migration backup and compatible code.

SQL bulk imports that bypass Active Record must supply an Account per user. Model creation and the migration enforce the normal application workflow; they do not add a cross-table database trigger.

## Validation

Coverage includes migration preservation/backfill, account creation without duplicates, invalid-account rollback, signup name requirements, duplicate-name acceptance, email uniqueness, Unicode names, social sign-in/linking, profile updates, email verification, user search, and author search reindexing. Frontend tests verify signup request fields and Account form population/editing.

### Verification of this change (6 October 2026)

- Frontend: 231 tests passed; production build and targeted lint passed.
- Account/authentication/migration backend regression set: 111 tests passed.
- Full backend: 1,131 examples, 50 failures, 2 pending. All 50 failures also reproduced against the unchanged repository in an isolated baseline database; there were no new failures after updating the old account-count expectation.
- Project-wide TypeScript checking still reports 325 existing errors.
- Local development migration: 16 users, 16 accounts, zero users without an account. Ten profiles have an unknown first or last name and need user completion. All article/review search vectors were rebuilt.
- A pre-migration local database backup was saved at `/private/tmp/wine-users-before-account-migration-20261006.dump` with owner-only permissions. This is a temporary local backup, not a production backup or deployment.
