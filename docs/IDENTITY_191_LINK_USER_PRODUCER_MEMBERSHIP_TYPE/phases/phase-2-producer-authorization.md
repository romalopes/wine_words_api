# Phase 2 — Producer Authorization Hardening

**Issue:** #191
**Status:** Complete
**Scope:** `wine_words_api`

## Goal

Stop treating "linked to this producer" as a blank cheque. Editing now requires an `owner` or `manager` membership (or existing global catalogue rights); contributors and unrelated users are read-only; deletion is catalogue-manager only.

## Bug found during the audit

`Api::V1::ProducersController` declared `before_action :ensure_wine_manager!` **before** `before_action :set_producer`. The helper's fallback was `return if @producer && current_user&.producers&.exists?(@producer.id)`, but `@producer` was always `nil` at that point, so the fallback was dead code: linked users could not actually edit anything, and the intended "linked users may edit" rule was inert. The new code fixes the ordering, which is what makes membership-based editing work at all.

## Implemented policy

| Action | Allowed |
|---|---|
| `index`, `show`, `search` | Public (unchanged) |
| `create` | `wine_manager?` (Admin / Editor / Reviewer — unchanged) |
| `update`, `attach_logo`, `remove_logo` | `wine_manager?` **or** an `owner`/`manager` membership **for this producer** |
| `destroy` | `catalogue_manager?` only (Admin / Editor) |

`contributor` membership → `403`. Membership of a different producer → `403`. No membership and no role → `403`.

## Files changed

| File | Change |
|---|---|
| `app/controllers/api/v1/producers_controller.rb` | `set_producer` runs first; `ensure_producer_editor!` / `ensure_catalogue_manager!`; `editable_membership_for`; `can_edit_producer?`; `can_edit` in `producer_json`. |
| `spec/requests/api/v1/producer_authorization_spec.rb` | New request spec (17 examples). |
| `spec/requests/api/v1/producers_spec.rb` | Unchanged (existing Admin CRUD coverage still passes). |

## Key code

```ruby
before_action :set_producer, only: [:show, :update, :destroy, :attach_logo, :remove_logo, :link_wine]
before_action :ensure_wine_manager!, only: [:create]
before_action :ensure_catalogue_manager!, only: [:destroy]
before_action :ensure_producer_editor!, only: [:update, :attach_logo, :remove_logo]
```

```ruby
def editable_membership_for(user, producer)
  return false unless user && producer

  user.producer_memberships
      .where(producer_id: producer.id, membership_type: ProducerMembership::EDITABLE_TYPES)
      .exists?
end
```

Authorization uses `real_current_user`, matching the rest of the API's admin gates: impersonation does not launder privileges, and an Admin who is impersonating someone keeps their real role.

## Server-derived `can_edit`

`producer_json` now returns:

```json
{ "can_edit": true }
```

`can_edit` is `real_current_user.wine_manager? || editable_membership_for(...)`, i.e. `false` for the public, contributors and unrelated users. The React app uses it for affordances only — every mutation is still gated on the server.

## Verification

```
bundle exec rspec spec/requests/api/v1/producer_authorization_spec.rb   # 17 examples, 0 failures
bundle exec rspec spec/requests/api/v1/producers_spec.rb               # existing CRUD: green (one pre-existing failure, see Phase 7)
```

Covered cases: owner/manager edit; contributor denied (PATCH + logo upload); owner of another producer denied; unrelated user denied; Reviewer/Editor/Admin retain edit; owner cannot delete; Reviewer cannot delete; Admin can delete; `can_edit` true/false per caller; 401 unauthenticated.

## Deviations

- **Reviewers can no longer delete producers.** They keep create/edit/logo rights, but deletion is Admin/Editor-only per issue #191. This is a deliberate, documented behaviour change.
- **Owners cannot delete.** Same rule: deletion is not a membership right.
- Owners and managers are indistinguishable in this release (no separate capability), matching the Phase 0 decision.
