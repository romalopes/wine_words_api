# Comments

Threaded comments on wines, reviews and articles. **One polymorphic `Comment`
model serves all three**, with one level of replies: `parent_id` `NULL` is a
top-level comment, otherwise it points at the comment being replied to.

The backend flattens the polymorphism, so the frontend never reconstructs the
hierarchy and never sends a `commentable_type`/`commentable_id` of its own.

## 1. Endpoints

All paths live under `/api/v1`. Reads require a Bearer JWT (the API-wide rule in
`ApplicationController`); writes additionally require a role allowed to comment.
The author always comes from the token — there is no `user_id` param.

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/wines/:id/comments` | wine thread (`:id` is slug or numeric id) |
| `POST` | `/wines/:id/comments` | comment on a wine |
| `GET` | `/reviews/:id/comments` | review thread |
| `POST` | `/reviews/:id/comments` | comment on a review |
| `GET` | `/articles/:id/comments` | article thread |
| `POST` | `/articles/:id/comments` | comment on an article |
| `POST` | `/comments/:id/replies` | reply to a comment |
| `PATCH` | `/comments/:id` | edit a comment |
| `DELETE` | `/comments/:id` | soft delete a comment |

```json
{ "comment": { "body": "I completely agree with this." } }
```

* A reply's commentable is **derived from the parent comment**, never taken from
  the request — a client cannot attach a reply to a different resource.
* Unknown resource → `404`; a draft review/article the caller cannot see → `404`
  (same `visible_to` rule as the likes endpoints).
* Unauthenticated → `401`. A `Guest` account → `403`.

## 2. Who may do what

`Comments::Permission` is the single source of truth. Two capabilities are kept
separate on purpose:

| | Comment / reply | Edit or delete **someone else's** comment |
|---|---|---|
| `Guest` | ❌ | ❌ |
| `Reader` | ✅ | ❌ |
| `Reviewer` | ✅ | ❌ |
| `Editor` | ✅ | ✅ |
| `Admin` | ✅ | ✅ |

* "May comment" is `User#commenter?` — **any role other than `Guest`**, not an
  allow-list, so a role added to the enum later cannot silently lose the ability.
* Privileged roles (`Reviewer`/`Editor`/`Admin`) are independent of the
  subscription, so a `Reviewer` on the FREE plan can still comment.
* Moderation (`User#comment_moderator?`) is `catalogue_manager?` = Editor/Admin.

## 3. The hierarchy rules

`Comment#parent_must_be_top_level` enforces both invariants in the model, so they
hold no matter which endpoint is called:

1. **No reply to a reply** — one level of nesting only, matching the UI and
   removing unlimited nesting as a spam vector.
2. **The parent must belong to the same commentable** — the classic polymorphic
   bypass. `commentable_type` is additionally validated against
   `COMMENTABLE_TYPES` (`Wine`, `Review`, `Article`), so it can never resolve to
   an arbitrary model.

## 4. Payload

`GET .../comments` returns the thread already nested, one query per level
(`includes(replies: :user)`):

```json
{
  "comments_count": 1,
  "comments": [
    {
      "id": 42,
      "body": "I really enjoyed this vintage.",
      "deleted": false,
      "parent_id": null,
      "commentable_type": "Wine",
      "commentable_id": 123,
      "author": { "id": 7, "name": "Anderson" },
      "created_at": "2026-10-01T12:30:00Z",
      "updated_at": "2026-10-01T12:30:00Z",
      "edited": false,
      "editable": true,
      "deletable": true,
      "replies": [ { "id": 43, "...": "..." } ]
    }
  ]
}
```

`editable` / `deletable` are resolved server-side per viewer, so the UI renders
exactly the actions the API would allow.

**Deletion is soft** (`deleted_at`). A deleted comment keeps its slot in the
thread and is rendered as `"[Comment deleted]"` with `deleted: true`, so replies
retain their context and the thread never silently reflows. Its original text is
never sent to the client, and a tombstone offers no actions.

## 5. Making another resource commentable

The `Comment` model has no per-type logic. To make e.g. `Producer` commentable:

1. Migration: `add_column :producers, :id, ...` is already there — nothing needed
   for comments themselves.
2. Model: `include Commentable` in `app/models/concerns/commentable.rb`.
3. Add the type to `Comment::COMMENTABLE_TYPES`.
4. Routes + a thin controller using the `CommentableActions` concern
   (see `Api::V1::WineCommentsController`), resolving slug-or-id like the likes
   controllers do.

## 6. Frontend

`CommentSection` (`components/comments/CommentSection.tsx`) is rendered on the
wine, review and article detail pages; the `kind` prop is the only difference
between them.

```
CommentSection
├── CommentForm        (top level)
└── CommentList
    └── CommentItem    ├── CommentActions
                       └── CommentForm (reply / edit)
```

`useComments` (`hooks/useComments.ts`) is the state layer and follows the
server-truth rule of `useLike`: a mutation never patches local state from a
client-side guess — the record the API returns replaces the one in the thread,
so `editable` / `deletable` / `deleted` are always current. A failed request
leaves the thread untouched and keeps the user's text in the textarea.

`canCommentAs()` mirrors `User#commenter?` on the client purely to decide what to
render; the API re-checks every action, so hiding a control is never the
security boundary.

Unit tests: `components/comments/CommentSection.test.tsx`.
Backend tests: `spec/models/comment_spec.rb`, `spec/requests/api/v1/comments_spec.rb`.

## 7. Deliberately deferred

* **Moderation states** (`hidden`, `flagged`) and a report flow — the soft-delete
  groundwork is in place; no schema change is needed to add them later.
* **Rate limiting** — worth adding before a public launch; `Comment::MAX_BODY_LENGTH`
  (2000) is the only volume guard today.