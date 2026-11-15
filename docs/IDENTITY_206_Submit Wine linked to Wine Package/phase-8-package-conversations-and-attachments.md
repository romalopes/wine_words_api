# Phase 8 — Package Conversations and Attachments

## Status

Partially implemented on November 14, 2026.

## Objective

Implement package-specific conversations between submitter and Wine Words, internal staff notes, attachments with private storage, signed access URLs, and message rendering security.

## Dependencies

Phase 0, Phase 1, Phase 3, Phase 6, Phase 7

## Backend Work

### Backend Work

1. **Conversation Model (NEW — the only genuinely new messaging table)**
   - `WinePackageMessage`: `wine_package_id`, `sender_id` (nullable User), `sender_type` (submitter/editor/admin), `body`, `internal_note` (boolean), `created_at`
   - Attachments via ActiveStorage (reuse existing `Imageable` / `wine_package_attachments` pattern where applicable)

2. **Endpoints**
   - `GET /api/v1/trade/packages/:id/messages` — list messages (paginated, chronological)
   - `POST /api/v1/trade/packages/:id/messages` — submitter or editor sends a message
   - `POST /api/v1/admin/trade/packages/:id/messages` — editor/admin send (may set `internal_note: true`)
   - `POST /api/v1/trade/packages/:id/messages/:message_id/attachments` — upload attachment
   - `GET .../attachments/:attachment_id` — signed, short-expiry download URL

3. **Authorization**
   - Submitter: send messages (`internal_note` always false), view own + editor replies
   - Editor/Admin: send messages with or without `internal_note`, view everything
   - Guest token: view/send messages for its single package only
   - **Internal notes never appear in submitter or guest responses**

4. **Attachments**
   - Private bucket (R2/S3) — never public URLs
   - Signed URLs with short expiry (e.g., 1 hour)
   - Validation: content type allowlist (PDF, images, docs), size limit (~10 MB, configurable)
   - Content-type verified server-side, not just extension
   - Malware scanning (ClamAV or cloud equivalent) where feasible

5. **Message rendering security**
   - Sanitize HTML on output (rails-sanitize or equivalent); no script execution; safe markdown if used

6. **Events — REUSE existing `WinePackageEvent`**
   - New message → `WinePackageEvent.record!(type: "message_sent", visibility: ...)` (internal for internal notes)
   - Triggers notification (Phase 9)

## Frontend Work

### Frontend Work

1. **Conversation Component**
   - Integrated into My Wine Packages detail (Phase 6) and Admin assessment (Phase 7)
   - Chronological thread; sender identification (submitter vs Wine Words)
   - Internal-note badge (staff only); attachment chips with download links
   - Composer: text area, attachment upload, send button

2. **Attachment Upload**
   - Drag-and-drop or file input; progress indicator
   - Validation feedback (type, size); multiple attachments per message

3. **Responsiveness**
   - Composer pinned at bottom on mobile; attachments as chips; touch-friendly

## Database and Migration Work

### Database and Migration Work

1. **Migrations**
   - Create `wine_package_messages` table with indexes on `wine_package_id`, `sender_id`, `created_at`
   - Foreign keys with appropriate `on_delete` behaviour
   - Attachments via existing ActiveStorage tables (no new attachment table required if using the `wine_package_attachments` pattern; otherwise a join table keyed to message id)

## API and Authorization Requirements

- Reuse existing authentication and role policies
- Public endpoints narrowly scoped
- Object-level authorization for package access
- Editor/Admin explicit policies for assessment/commercial actions
- Internal notes staff-only
- Guest tokens: single package, scoped permissions, hashed, expiry, revocation
- No auto-login for existing accounts based on email submission

## Security Requirements

### Security Requirements

- Private storage only — no public attachment URLs
- Signed URLs with short expiry; authorization checked on every message/attachment endpoint
- Internal notes never exposed to submitter or guest APIs
- Guest tokens can only access messages for their single package
- XSS prevented in all message-body rendering; attachment content-type verified server-side
- Consistent attachment size limits across all upload endpoints

## Testing Requirements

### Testing Requirements

1. **Request Tests**
   - Submitter can send/view messages; editor sees all including internal
   - Internal notes absent from submitter and guest API responses
   - Attachment upload with type/size validation; invalid types/oversized rejected
   - Signed URL generation and expiry enforced
   - Guest token message access scoped to its single package
   - Cross-package message/attachment access denied

2. **Frontend Tests**
   - Conversation renders; composer works; upload with progress
   - Internal-note badge visible for staff only; download links work
   - Mobile layout verified

3. **Security Tests**
   - XSS payload in message body rendered inert
   - Signed URLs expire; direct storage access impossible

## Deployment/Configuration Requirements

### Deployment/Configuration Requirements

- ActiveStorage configured for private bucket (R2/S3)
- CORS for direct upload if used; signed-URL expiry configured
- Malware-scanning service if adopted
- Attachment size limits consistent across Rails, proxy, and edge layers

## AI Implementation Prompt

```
Implement package conversations and attachments for the Wine Words Trade portal.

Requirements:
- Package-specific messages between submitter and Wine Words (NEW WinePackageMessage table)
- Internal staff notes (internal_note flag, staff-only visibility)
- Attachments with PRIVATE storage (ActiveStorage + R2/S3), signed download URLs with short expiry
- Attachment type/size validation and malware scanning where feasible
- XSS-safe message rendering (sanitize all user content)
- Guest token access to messages for its single package only
- Notifications on new messages (Phase 9 integration)

Deduplication constraints (from Phase 1):
- REUSE existing WinePackageEvent via WinePackageEvent.record! (type: message_sent) — do NOT create a parallel event/notification store
- Reuse the existing ActiveStorage / wine_package_attachments patterns where applicable
- This is the ONLY new messaging table; internal assessment notes from Phase 7 remain separate (event-based, visibility: internal)

Deliver:
- Message model + endpoints (list, send, upload, download)
- ActiveStorage private-bucket configuration and signed-URL service
- Message sanitization
- Frontend conversation component with composer and attachment upload
- Request specs for all endpoints
- Security tests (XSS, attachment validation, signed-URL expiry, cross-package denial, internal-note isolation)
- Frontend component tests
```

## Acceptance Criteria

- [ ] Submitter can send/receive messages
- [ ] Editor/Admin can send messages and internal notes
- [ ] Internal notes only visible to staff
- [ ] Attachments upload with type/size validation
- [ ] Attachments stored privately; signed URLs expire
- [ ] XSS prevented in message rendering
- [ ] Guest token grants message access for a single package only
- [ ] Cross-package access denied
- [ ] Notifications triggered on new messages
- [ ] All tests pass

## Exit Gate

- Conversations and private attachments remain isolated to the correct package and roles
- Attachments secure and validated
- XSS prevention verified
- Notification integration working

## Implementation Notes

- Reuse existing Wine Words ActiveStorage and notification patterns
- Phase 7 internal **assessment notes** (event-based, visibility: internal) are distinct from Phase 8 conversation internal notes — keep both, document the distinction
- Attachment size limits must be consistent across all upload endpoints in the portal

## Validation Results

- Commands executed: `cd /Users/romalopes/Documents/studies/my_project/wine_project/wine_words && npm run build`; `cd /Users/romalopes/Documents/studies/my_project/wine_project/wine_words_api && bundle exec rspec spec/requests/api/v1/trade_spec.rb`
- Result: frontend build passed; Trade request suite has been exercised during backend stabilization.
- Implemented: submitter/guest conversation read and send UI, internal-note exclusion inherited from the API serializer/query boundary, and message event display.
- Not implemented: attachment upload, private storage/signed download links, malware scanning, admin conversation UI, and frontend conversation tests.
- Unresolved issues: do not advertise attachments as available until the backend attachment endpoints and private storage configuration are implemented. The current backend request suite also reports guest-message authorization failures that must be fixed before this phase can exit.
