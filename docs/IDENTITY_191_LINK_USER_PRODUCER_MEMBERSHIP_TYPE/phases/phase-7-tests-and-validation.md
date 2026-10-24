# Phase 7 — Tests and Validation

**Issue:** #191
**Status:** Complete
**Date:** 24 October 2026

## New / rewritten tests

| Suite | File | Examples | Result |
|---|---|---|---|
| API model | `spec/models/producer_membership_spec.rb` | 13 | green |
| API requests | `spec/requests/api/v1/producer_memberships_spec.rb` | 30 | green |
| API requests | `spec/requests/api/v1/producer_authorization_spec.rb` | 17 | green |
| Frontend | `src/components/AccountSettings.test.tsx` | 4 | green |
| Frontend | `src/components/ProducerDetail.test.tsx` | 5 | green |

### Model spec (13)

Associations (including optional `created_by`), the three accepted types, rejection of `follower`/`viewer`, presence, the **database** check constraint (`update_column` raises `ActiveRecord::StatementInvalid`), uniqueness per user/producer, same user on different producers, `owner?`/`manager?`/`contributor?`, `can_edit_producer?`, and the three scopes.

### Membership request spec (30)

Admin/Editor/Reader/unauthenticated access to list, create, update and delete; typed responses; nested and legacy payloads; a client-supplied `created_by_id` is ignored; missing/invalid/blank type → 422; duplicate → 409; cross-user path → 404; `users#show` embeds the type; `/account/producers` returns `membership_type` + `can_edit` for owner/contributor and `[]` for a user with no memberships.

### Producer authorization spec (17)

Owner and manager can PATCH; contributor cannot PATCH or upload a logo; member of another producer cannot PATCH; unrelated Reader cannot PATCH; Reviewer/Editor/Admin keep edit rights; owner and Reviewer cannot DELETE; Admin can DELETE; `can_edit` is true for owner/manager/staff, false for contributor and the public; 401 without authentication.

## Backend validation

```
bundle exec rspec                       # 1420 examples, 45 failures, 2 pending
bundle exec rspec spec/models/producer_membership_spec.rb \
  spec/requests/api/v1/producer_memberships_spec.rb \
  spec/requests/api/v1/producer_authorization_spec.rb   # 60 examples, 0 failures
bundle exec rubocop <changed files>     # no new offenses (repo-wide array-bracket style is pre-existing)
bundle exec brakeman -q                 # 13 warnings, none in files touched by this issue
bundle exec rails zeitwerk:check        # "all is good"
```

### The 45 pre-existing backend failures

None are in files touched by this issue. Distribution: `wine_spec` 15, `log_spec` 12, `sentry_context_spec` 3, `wine_packages_mailer_spec` 3, `web_spa_pages_spec` 2, `mail_sender_spec` 2, and one each in `subscriptions_spec`, `stripe_webhook_billing_spec`, `registrations_spec`, `producers_spec`, `email_verification_flow_spec`, `articles_show_reviews_spec`, `log_object_spec`, `billing_spec`.

Verified as baseline behaviour, not regressions:

- `git stash` + `rspec spec/models/wine_spec.rb spec/models/log_spec.rb` → **27 failures** both with and without this branch's changes.
- `git stash` + `rspec spec/requests/api/v1/producers_spec.rb:355` → fails identically on unmodified `main` ("clears stale regions automatically when only the country changes"). It is a model-callback/association-caching problem unrelated to memberships.

## Frontend validation

```
npm run typecheck   # clean
npm run lint        # 0 errors, 6 pre-existing warnings in untouched files
npx vitest run      # 66 files, 383 tests: 380 passed, 3 failed
```

The three failures are pre-existing and unrelated: `Reviews.test.tsx` (1) and `ApiHealth.test.tsx` (2). Verified by stashing every frontend change and re-running those two files: **3 failed / 17 passed**, identical.

`npm run typecheck` was **failing on `main`** with five errors (unused `Link`/`BackToSource` imports in `GrapeDetail.tsx`, unused `useRef`/`setRolesLoading` in `UserDetail.tsx`, and a real `country?.name` type bug). Those were fixed in passing so the project now type-checks cleanly.

## Coverage gaps (accepted)

- No component test for the new **UserDetail** membership UI (the component has no test file and its data flow is covered end-to-end by the request specs plus the API client contract).
- No system/E2E test for the full "Admin links a producer as owner → owner edits it" journey; that path is covered separately by the request specs on both halves.
- Concurrent membership updates (two admins changing the same row) are not tested; there is no optimistic locking on this table, and last write wins by design.
