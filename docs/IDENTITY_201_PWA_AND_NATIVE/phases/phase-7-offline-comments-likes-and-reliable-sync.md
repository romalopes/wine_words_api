# Phase 7 — Offline Comments/Likes and Reliable Sync

**Status:** ✅ Implemented
**Date:** 2026-11-03
**Repositories:** [wine_words (frontend)](https://github.com/romalopes/wine_words_frontend) · [wine_words_api](https://github.com/romalopes/wine_words_api)
**Gate:** B — Installable / offline PWA
**Master plan:** [`../Wine_Words_Mobile_PWA_Implementation_Plan.md`](../Wine_Words_Mobile_PWA_Implementation_Plan.md) · Issue [#201](https://github.com/romalopes/wine_words_api/issues/201)

---

## 1. Objective and scope

Add a durable **outbox** for offline comment and like writes, synced safely with
idempotency and operation-specific conflict policies. Rails remains canonical and
reauthorizes every mutation.

## 2. Prerequisites

- Phase 5 (outbox table) and Phase 6 (offline reads).

## 3. Tools to install

**None** on the frontend. Minimal **Rails idempotency support** may be added for
creates (comments) if absent — no new gem required.

## 4. Task breakdown

1. Durable outbox operation: client UUID, **idempotency key**, account scope,
   dependency ordering, retry count, status, error, timestamp.
2. Backend idempotency storage/check for creates; comments require reauthorization
   on sync.
3. Likes reconcile **desired final state** (not replayed toggles); edits use
   optimistic version checks where supported.
4. Sync triggers: foreground startup, reconnect, visibility-resume, manual retry
   (browser Background Sync only as enhancement).
5. UI states: pending / sent / failed / conflict — never silently drop writes.
6. Never store auth secrets in the outbox; handle network timeout after a
   successful server commit.

## 5. Outbox operation shape (from the master plan)

```typescript
interface OutboxOperation {
  id: string;                 // local UUID
  idempotencyKey: string;     // server-recognized
  accountId: string;
  entityType: 'comment' | 'like' | 'quiz_result' | 'wine_package';
  entityId?: string;
  action: string;
  payload: unknown;
  expectedVersion?: string | number;
  createdAt: string;
  attempts: number;
  status: 'pending' | 'syncing' | 'failed' | 'conflict';
  lastError?: string;
}
```

## 6. Files to change

| File | Action |
|---|---|
| `src/offline/outbox.ts` | New (queue + state machine) |
| `src/offline/syncManager.ts` | New (triggers, retry/backoff) |
| `src/hooks/useComments.ts`, `src/hooks/useLike.ts` | Modify (route through outbox when offline) |
| `src/components/comments/CommentForm.tsx` | Modify (pending/failed states) |
| `src/components/SyncStatus.tsx` | New |
| API: idempotency for comment create | Modify (if absent) |

## 7. Feature flags

- `VITE_OFFLINE_ENABLED`; backend kill-switch to disable offline write processing.

## 8. Tests

- No duplicate comments under retries; unlike/like reconciliation.
- Offline drafts survive restart; expired permissions preserve draft but reject publish.
- Failed writes visible; network-timeout-after-commit handled.

## 9. Acceptance criteria

- No duplicate comments under retries; like toggles reconcile.
- Offline drafts survive restart; rejected writes are surfaced.
- No generic last-write-wins; no offline admin actions.

## 10. Risks, compatibility, rollback

- **Risk:** duplicate writes. **Mitigation:** server-side idempotency keys.
- **Risk:** stale permission. **Mitigation:** reauthorize on sync; preserve draft.
- **Rollback:** disable offline write processing via backend switch; queued drafts
  remain until recoverable.

## 11. AI coding prompt (from the master plan)

> Implement safe offline comment and like writes for Wine Words, reusing existing
> Rails endpoints and permission rules. First audit actual API schemas. Add a
> durable Dexie outbox with UUID/idempotency keys, retry/backoff, account scoping,
> UI pending/error states, reconnect and foreground sync. Add minimal Rails
> idempotency support where needed; likes should reconcile desired state and
> comments should not duplicate on retry. Test network timeouts, logout, expired
> session, role changes and conflict handling. Do not implement generic
> last-write-wins or offline admin actions.

## 12. Gate checklist

- ⬜ Outbox durable + idempotent
- ⬜ Like reconciliation verified
- ⬜ Pending/failed/conflict UI tested
- ⬜ Gate B (Phases 4–8) ready for review
