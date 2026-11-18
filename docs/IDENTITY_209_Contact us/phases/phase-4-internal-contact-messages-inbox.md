# Phase 4 — Internal Contact Messages Inbox

**Status:** Complete
**Date:** 2026-11-17
**Repository:** React frontend (local `wine_words/`)

---

## 1. Navigation and route guard

* `src/constants/roles.ts` — new `canManageContactMessages` (alias of
  `canManageAllPackages`: Admin/Editor only). Reviewers keep content rights but
  cannot open the inbox.
* Desktop Settings dropdown (`Header.tsx`): **Contact Messages** appended after
  Wine Profiles, rendered only when `canManageContactMessages(effectiveIdentity)`.
  Using the effective identity keeps impersonation behaviour consistent with the
  rest of the menu.
* Mobile `MoreMenu.tsx`: **Contact Messages** in the Staff group under the same
  guard.
* Routes (`AppRoutes.tsx`):
  * `/settings/contact-messages` → `ContactMessages`
  * `/settings/contact-messages/:id` → `ContactMessageDetail`
* Both components render a "restricted to Editor and Admin accounts" panel for
  anyone else, and never call the API in that case. The server remains the real
  boundary (`ContactMessagePolicy` → 403).

## 2. List — `src/components/ContactMessages.tsx`

* `usePagedList` + `Pagination`, page state in the URL (`?page=`), 20 per page.
* Filters in the URL: `status`, `contact_type`, `search` (so a filtered inbox can
  be shared or reloaded).
* Status tabs: **All / Unread / Read / Archived**; the Unread tab shows the
  unread badge from the API's `unread_count` (archived messages never count).
* Search covers sender name, email and subject (server-side, case-insensitive).
* Rows: sender name + email, category label, subject (link), received date,
  status badge, Open action. Unread rows are highlighted.
* Loading ("Loading messages…"), empty ("No messages match these filters.") and
  error + Retry states. Table is horizontally scrollable on phones.

## 3. Detail — `src/components/ContactMessageDetail.tsx`

* Loads `GET /api/v1/admin/contact_messages/:id`.
* Shows sender name, `mailto:` link, category, received date, status badge and the
  full body inside a `white-space: pre-wrap` block. React renders it as text —
  no `dangerouslySetInnerHTML`, and a spec asserts that a `<script>` payload
  produces no script node.
* Actions: **Mark as read**, **Mark as unread**, **Archive**, **Back to inbox**.
  Each calls `PATCH`, waits for the server response, then updates the view; the
  relevant button is disabled while the message is already in that state, and a
  failed request surfaces a `role="alert"` message without changing the status.
* The body is deliberately not marked read on open — an explicit action is
  predictable and avoids write-on-view side effects.

## 4. API client

`src/services/contactApi.ts`:

```ts
contactApi.list({ status, contact_type, search, page, per_page }) // auth
contactApi.get(id)                                               // auth
contactApi.updateStatus(id, "read" | "unread" | "archived")      // auth
```

The list response type extends the shared `Paginated<T>` with `unread_count`.

## 5. Tests — `ContactMessages.test.tsx`, `ContactMessageDetail.test.tsx`

Covered: Editor/Admin access, Reader and anonymous denial (and no API call),
list rendering with sender/category/subject, unread badge, status filtering,
search, empty state, error + Retry, detail rendering as plain text, mark-as-read
and archive after server confirmation, failed action handling.

Result: **21 examples, 0 failures** across the Phase 3/4 component specs.
