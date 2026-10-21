# Likes

Polymorphic likes on wines, reviews and articles. One user can like a given
resource at most once (model validation + DB unique index
`index_likes_on_user_and_likeable`). Like counts are cached in
`wines/reviews/articles.likes_count` via `counter_cache`, so reads never run
`COUNT(*)`.

## 1. Endpoints

All paths live under `/api/v1`. Reads are public; mutations require a Bearer
JWT. The user always comes from the token — there is no `user_id` param.

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/wines/:id/like` | like a wine (`:id` is slug or numeric id) |
| `DELETE` | `/wines/:id/like` | unlike a wine |
| `POST` | `/reviews/:id/like` | like a review |
| `DELETE` | `/reviews/:id/like` | unlike a review |
| `POST` | `/articles/:id/like` | like an article |
| `DELETE` | `/articles/:id/like` | unlike an article |

Both verbs are **idempotent** and always return `200`:

```json
{ "liked": true, "likes_count": 12 }
```

* Repeat `POST` keeps exactly one Like (a `RecordNotUnique` race is rescued).
* `DELETE` with no existing Like still returns `{ "liked": false, ... }`.
* Unknown resource → the normal `404` (`{ "error": "… not found" }`).
* Liking a draft review/article the caller cannot see → `404` (same rule as
  `show`, via `visible_to`; `wine_manager?` bypasses).

Unauthenticated `POST`/`DELETE` → `401`.

## 2. Read payloads

Every wine/review/article representation (list + detail, including `grouped`,
`search`/`advanced_search`, `my_*`) carries:

```json
{ "likes_count": 27, "liked_by_current_user": true }
```

Anonymous requests get the count with `liked_by_current_user: false`.
The liked flag is preloaded in one query per resource type
(`Likes.liked_ids_for`), so collections stay N+1-free.

## 3. Making another resource likeable

The `Like` model has no per-type logic. To make e.g. `Comment` likeable:

1. Migration: `add_column :comments, :likes_count, :integer, null: false, default: 0`.
2. Model: `include Likeable`.
3. Routes + thin controller using the `LikeableActions` concern
   (see `Api::V1::WineLikesController`).

## 4. Frontend

`LikeButton` (`components/LikeButton.tsx` + `hooks/useLike.ts`,
`services/likesApi.ts`) renders `♡/♥ count` on wine/review/article detail and
list cards. Anonymous users see a read-only count. The API response is the
authoritative state (no optimistic `+1`); failures keep the previous state and
show an inline error; the button is disabled while a request is in flight.
Unit tests: `components/LikeButton.test.tsx`.
