# Phase 2 — Follow API and Authorization

**Status:** Completed  
**Date:** 2026-10-25  

---

## 1. Routes (config/routes.rb)

```ruby
resources :follows, only: [:index, :create, :destroy] do
  collection do
    get :status
    get :statuses
  end
end
```

Verified with `bin/rails routes`:

| Method | Endpoint | Controller action |
|--------|----------|-------------------|
| GET | `/api/v1/follows` | `index` (paginated, `?type=` filter) |
| POST | `/api/v1/follows` | `create` (idempotent) |
| DELETE | `/api/v1/follows/:id` | `destroy` |
| GET | `/api/v1/follows/status` | `status` (single target) |
| GET | `/api/v1/follows/statuses` | `statuses` (batch) |

---

## 2. Controller: app/controllers/api/v1/follows_controller.rb

- `create`: resolves the target by slug or id, returns 201 for a new Follow and 200 for an existing one (idempotent). `RecordNotUnique` from a concurrent duplicate is rescued and re-read.
- `destroy`: only the current user's own Follow; other users' rows are 404.
- `status`: single-target follow state for detail pages.
- `statuses`: batch follow state for list pages (`?followable_type=Wine&ids[]=`).
- `find_followable` mirrors the likes/comments controllers: `visible_to(current_user)` unless `wine_manager?`; drafts are **404**, never 403 (existence not revealed). Unknown types are 400.
- `user_id` is never accepted from the client — the Follow always belongs to `current_user`.

## 3. Serializer: app/serializers/follow_serializer.rb

Returns `id`, `followable_type`, `followable_id`, `target_label` (name/title), `target_slug`, `target_path` (frontend route: `/producers/:slug`, `/wines/:slug`, `/reviews/:slug`, `/articles/:slug`), `following: true`, `created_at`.

---

## 4. Tests

**spec/requests/api/v1/follows_spec.rb — 21 examples, 0 failures**

Covers:
- Create for each target type; slug and id resolution
- Idempotent POST (201 then 200, one row)
- 400 invalid type, 404 missing target
- Draft review 404 for other users; allowed for wine managers
- `user_id` from client ignored
- Index scoped to current user, type filter, pagination, auth required
- Destroy own follow; 404 for another user's follow
- Status true/false, 404 for hidden targets
- Statuses batch + invalid type rejection

---

## 5. Gate: Phase 2 Complete

- [x] Routes registered
- [x] FollowsController implemented
- [x] FollowSerializer implemented
- [x] Request specs pass (21/21)
- [x] ProducerMembership behavior unchanged