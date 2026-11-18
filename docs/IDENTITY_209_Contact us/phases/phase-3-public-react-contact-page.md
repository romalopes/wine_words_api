# Phase 3 — Public React Contact Page

**Status:** Complete
**Date:** 2026-11-17
**Repository:** React frontend (local `wine_words/`)

---

## 1. Navigation

* Desktop: `src/components/Header.tsx` now renders
  `<NavLink to="/contact">Contact</NavLink>` **immediately before** About.
* Mobile: `src/components/mobile/MoreMenu.tsx` "About" group lists Contact first,
  then About Wine Words.

## 2. Route

`src/components/AppRoutes.tsx`:

```tsx
<Route element={<Contact />} path="/contact" />
```

Public — no auth guard, works for anonymous and signed-in visitors, and is not
wrapped by any staff check.

## 3. Files

| File | Purpose |
|---|---|
| `src/components/Contact.tsx` | Form, validation, submit states, privacy note, honeypot, success panel |
| `src/components/contact.module.css` | Responsive styles shared with the inbox |
| `src/components/Turnstile.tsx` | Turnstile widget loader (public site key only) |
| `src/services/contactApi.ts` | `create`, `list`, `get`, `updateStatus` |
| `src/constants/contact.ts` | Categories + labels mirroring `ContactMessage::CONTACT_TYPES`; status filters |
| `src/types/contact.ts` | `ContactMessage`, `ContactMessageInput`, list envelope, receipt |
| `src/services/api.ts` | Registers `contactApi` |
| `src/vite-env.d.ts`, `.env.example` | `VITE_TURNSTILE_SITE_KEY` typed and documented |

## 4. Behaviour

* Fields: name (120), email (254), category (allowlist), subject (180), message
  (10 000) — all required; lengths and `maxLength` mirror the API.
* Client validation (including a safe email regex) improves usability; the API
  remains authoritative. Server `details` are mapped back onto the offending
  inputs; the generic `error` is shown in a `role="alert"` banner.
* **Signed-in visitors do not retype their identity.** When `useAuth().user` is
  present, both the name and email fields become read-only displays of the
  account identity — the name from `display_name`, `first_name`, or the email
  local-part, and the email with the hint "We will reply to your account email."
  Client validation skips both requirements and the payload always uses the
  account identity. Anonymous visitors keep the normal editable, required
  name and email inputs.
* One pending request at a time (`busy` guard + disabled button) — duplicate
  clicks are impossible.
* Success appears only after `POST /api/v1/contact_messages` resolves; it is a
  `role="status"` panel with a "Send another message" action.
* Errors never expose internals; retry is simply pressing Send again.
* Honeypot: `website` input positioned off-screen, `aria-hidden` container,
  `tabIndex={-1}`, `autoComplete="off"` — invisible to people and AT, fillable by
  naive bots. The API discards such submissions silently.
* Accessibility: `<label htmlFor>` on every field, `aria-invalid`,
  `aria-describedby` error/hint wiring, visible focus rings, keyboard-operable
  select and buttons, and a responsive single-column layout below 700 px.
* Privacy note explains that the details are used only to answer the enquiry.

## 5. Turnstile

* `VITE_TURNSTILE_SITE_KEY` is the **only** key in the browser. The secret lives
  in the Rails API (`TURNSTILE_SECRET_KEY`).
* The script (`api.js?render=explicit`) is loaded once per session; the widget is
  rendered with `action="contact"` and emits tokens through `onToken`.
* Expiry/error emit `null`; after any failed submission the component is reset
  with a new `resetKey` so a fresh single-use token is required.
* Without a site key the widget renders a short note and emits no token — the API
  fails closed in production (see Phase 5).

## 6. Tests — `src/components/Contact.test.tsx`, `Turnstile.test.tsx`

Covered: form rendering, every server-supported category, client validation
blocks the API, invalid email, success only after confirmation, server field
errors mapped, pending state blocks duplicate submits, widget not configured,
widget rendered with the public key, token/expiry forwarding, cleanup on unmount,
and the signed-in path (read-only account email, submission without retyping it,
payload carries the account address).

Result: **23 examples, 0 failures** (Contact, ContactMessages,
ContactMessageDetail, Turnstile), `eslint` clean, and no TypeScript errors in the
new files.

```bash
npx vitest run src/components/Contact.test.tsx src/components/Turnstile.test.tsx
npx eslint src/components/Contact.tsx src/components/Turnstile.tsx
```
