# Phase 4 — `/account/producers` Payload

**Issue:** #191
**Status:** Complete
**Scope:** `wine_words_api`

## Goal

Keep the existing endpoint (no replacement, per the Phase 0 decision) but add the membership type and the server-derived edit capability so `/account` can render the right badge and affordance.

## Change

`Api::V1::AccountsController#my_producers` now iterates **memberships**, not producers, because the type lives on the join row:

```ruby
def my_producers
  memberships = current_user.producer_memberships
                            .includes(producer: :country)
                            .order(:id)
  render json: memberships.map { |membership| producer_summary_json(membership) }
end
```

`includes(producer: :country)` keeps this at three queries regardless of how many producers the user belongs to.

## Response

```json
[
  {
    "id": 42,
    "name": "Domaines Ott",
    "slug": "domaines-ott",
    "country": "France",
    "email": "contact@domaines-ott.example",
    "producer_type": "winery",
    "founded_year": 1896,
    "membership_id": 12,
    "membership_type": "owner",
    "can_edit": true
  }
]
```

Field notes:

- `membership_id` lets the UI correlate a row with a membership without guessing.
- `membership_type` is always owner/manager/contributor.
- `can_edit` is `membership.can_edit_producer? || current_user.wine_manager?` — catalogue staff keep their global rights even if their own membership is `contributor`.
- The previous fields (`id`, `name`, `slug`, `country`, `email`, `producer_type`, `founded_year`) are unchanged, so existing consumers keep working.

## Files changed

| File | Change |
|---|---|
| `app/controllers/api/v1/accounts_controller.rb` | `my_producers` + `producer_summary_json(membership)`. |

## Verification

```
bundle exec rspec spec/requests/api/v1/producer_memberships_spec.rb   # includes account/producers cases
```

Cases covered: owner → `membership_type: "owner"`, `can_edit: true`; contributor → `can_edit: false`; no memberships → `[]`.

## Notes

- `current_user` (effective user) is used here rather than `real_current_user`, because the payload describes what the *signed-in-as* user may do in their own account view. Mutation authorization still uses `real_current_user` server-side.
- Ordering by `membership.id` gives a stable list; the UI does not re-sort by type.
