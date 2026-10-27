# Phase 5 — React Admin Interface

**Status:** ✅ Complete (frontend: `wine_words`) · **Rev 2:** dialog restyled with the project's `.dialog-backdrop`/`.dialog` classes and hard-delete action wired

## Files

| File | Change |
|---|---|
| `src/services/accountApi.ts` | `usersApi.softDelete`, `hardDelete`, `reactivate` client methods |
| `src/types/api.ts` | `UsersApi` extended with the three methods |
| `src/types/user.ts` | `UserDetail.deleted_at?: string \| null` |
| `src/components/UserDetail.tsx` | Account Lifecycle section + delete dialog |

## UI behaviour (admin-only)

* **Account Lifecycle section** renders only when `isAdminUser`.
* **Active account** → *Delete account* opens the delete **dialog** (reuses the shared
  `dialog-backdrop` / `dialog` styles from `LinkProducerDialog` — an earlier rev used
  unstyled `modal-*` classes that rendered invisibly).
* The dialog offers two actions:
  * **Soft delete** — reversible; stamps `deleted_at`, revokes access, schedules the
    30-day `DeleteUserJob`.
  * **Delete permanently** (hard delete) — guarded by a `window.confirm` second
    confirmation because it is irreversible.
* Backend failures surface inside the dialog via `errorText`/`errorData`:
  `403 hard_delete_disabled`, `422`, and **`409 blocked` renders the structured
  `blocking_reasons` list** (e.g. "3 reviews authored by this user") so the admin knows
  what to resolve first.
* **Soft-deleted account** → shows the deletion timestamp (from `GET /users/:id`'s
  `deleted_at`) and a *Reactivate user* button.
* Successful hard delete navigates back to `/users`; the record no longer exists.
* Non-admins never see the section (JSX guard) and get API 403s regardless.

## Enabling hard delete (flag)

`hard_delete_enabled` is not a `RESERVED_KEYS` member, so admins can enable it either:

* **Configuration page** → custom settings → key `hard_delete_enabled`, value `true`; or
* Rails console: `AppSetting.set!("hard_delete_enabled", "true")`.

## Verification

* `npx tsc --noEmit` — clean.
* `npx vitest run src/components/UserDetail.test.tsx` — passing.
* Full frontend suite: 408 passed; the 4 failures (`ProducerDetail`, `Reviews`,
  `ApiHealth`) exist on the pristine tree and are unrelated (verified via `git stash`).