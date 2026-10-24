# Phase 3 — Membership Administration API

**Issue:** #191
**Status:** Complete
**Scope:** `wine_words_api`

## Goal

Expose `membership_type` on create/update/list responses, accept it on writes, and keep the actor server-derived.

## Endpoints

| Method | Path | Access |
|---|---|---|
| `GET` | `/api/v1/users/:user_id/producer_memberships` | Admin / Editor |
| `POST` | `/api/v1/users/:user_id/producer_memberships` | Admin / Editor |
| `PATCH` | `/api/v1/users/:user_id/producer_memberships/:id` | Admin / Editor (new) |
| `DELETE` | `/api/v1/users/:user_id/producer_memberships/:id` | Admin / Editor |
| `GET` | `/api/v1/producers/:id/memberships` | Reviewer / Editor / Admin (read-only, unchanged) |

`config/routes.rb` gained exactly one line:

```ruby
patch 'producer_memberships/:id', to: 'producer_memberships#update'
```

## Payloads

Create (preferred, nested):

```json
{ "producer_membership": { "producer_id": 42, "membership_type": "manager" } }
```

Create (legacy flat form still accepted for compatibility):

```json
{ "producer_id": 42, "membership_type": "manager" }
```

Update:

```json
{ "producer_membership": { "membership_type": "owner" } }
```

`membership_params` picks the nested object when present and otherwise falls back to top-level params, permitting only `producer_id` and `membership_type`.

## Response shape

```json
{
  "id": 12,
  "user": { "id": 7, "display_name": "Ada", "email": "ada@example.com" },
  "producer": { "id": 42, "name": "Domaines Ott", "slug": "domaines-ott", "country": "France" },
  "membership_type": "manager",
  "can_edit": true,
  "created_by": { "id": 1, "display_name": "Admin" },
  "created_at": "2026-10-24T08:00:00.000Z",
  "updated_at": "2026-10-24T08:00:00.000Z"
}
```

`GET /api/v1/users/:id` embeds the same `membership_type` / `can_edit` / `updated_at` fields inside `producer_memberships`.

## Behaviour

- **Actor is server-derived.** `created_by` is always `real_current_user`; a client-supplied `created_by_id` is dropped by strong parameters. Covered by a request spec.
- **Duplicate membership → `409 Conflict`** with `{ "errors": ["This user is already linked to this producer"] }`. A pre-check handles the normal path; `ActiveRecord::RecordNotUnique` is rescued so a race between two admins also returns 409 instead of a 500.
- **Missing type → `422`** `"Membership type can't be blank"`.
- **Missing `producer_id` → `422`** `"Producer can't be blank"` (instead of a confusing 404).
- **`follower` / `viewer` → `422`** `"Membership type must be owner, manager, or contributor"`.
- **Wrong user in the path → `404`.** Memberships are always resolved through `user.producer_memberships`, so `PATCH /users/OTHER/producer_memberships/ID` cannot mutate someone else's row.
- **No follow side effects.** Nothing in this controller creates a Follow record (none exists).

## Files changed

| File | Change |
|---|---|
| `config/routes.rb` | PATCH route. |
| `app/controllers/api/v1/producer_memberships_controller.rb` | `membership_params`, typed create, new `update`, 409 handling, typed JSON. |
| `app/controllers/api/v1/users_controller.rb` | `producer_memberships` payload extended. |
| `spec/requests/api/v1/producer_memberships_spec.rb` | Rewritten (30 examples): list, create, update, delete, users#show, account/producers. |

## Verification

```
bundle exec rspec spec/requests/api/v1/producer_memberships_spec.rb   # 29 examples, 0 failures
```

## Deviations / notes

- The flat create payload is kept because the current React client used it; the client was migrated to the nested shape in Phase 5, so the fallback can be retired in a later cleanup.
- Only Admin/Editor may administer memberships. Owners/managers cannot grant themselves or others a role — explicitly out of scope for this release.
- No "last owner" protection: producers are not required to have an owner, so removing the final owner is allowed.
