# Phase 6 — Frontend: Account Page, Producer Detail, Delete Gating

**Issue:** #191
**Status:** Complete
**Scope:** `wine_words` (React)

## `/account` — My Producers

`src/components/AccountSettings.tsx` now:

- renders the membership badge next to the country, e.g. `France · OWNER`;
- shows **Edit** only when the API says `can_edit` is true.

```tsx
{producer.can_edit && (
  <Link to={`/producers/${producer.slug}/edit`} className="btn btn-secondary btn-sm">Edit</Link>
)}
```

A `contributor` therefore still sees the association and the producer link, but no edit affordance. Admins/Editors keep Edit even when their own membership is `contributor`, because the API computes `can_edit` from role **or** membership.

The section still has no way to change a membership type or link another user — membership administration is Admin/Editor work on `/users/:id`. There is no "Following" section.

## Producer detail — linked users

`src/components/ProducerDetail.tsx`:

- the **Linked Users** list shows a membership badge per row (`Owner` / `Manager` / `Contributor`);
- the page-level edit capability is now `canManageWinesRole(user) || producer?.can_edit === true`, so an owner/manager who is only a Reader sees the same editor affordances (regions, grapes, images, logo, Edit Producer) that catalogue staff see;
- **Delete Producer** is gated separately on `canDeleteProducers(user)` (Admin/Editor only), matching the server rule from Phase 2. Reviewers and owners/managers no longer see the delete button.

## Files changed

| File | Change |
|---|---|
| `src/components/AccountSettings.tsx` | Badge + conditional Edit link. |
| `src/components/ProducerDetail.tsx` | Badges in the linked-users list; `can_edit`-aware editor affordances; delete gated on Admin/Editor. |
| `src/constants/roles.ts` | `canDeleteProducers`. |
| `src/index.css` | Badge styling (see Phase 5). |

## Tests

| File | Coverage |
|---|---|
| `src/components/AccountSettings.test.tsx` | New "My Producers" case: owner + contributor rows render both badges, and only the owner row has an Edit link. |
| `src/components/ProducerDetail.test.tsx` | New case: linked users are labelled `Owner` / `Contributor`. The auth mock became mutable so the Linked Users section can be exercised; `getMemberships` is now mocked for every test (removes noisy unhandled-rejection logs). |

```
npx vitest run src/components/AccountSettings.test.tsx src/components/ProducerDetail.test.tsx
# 2 files, 9 tests passed
```

## Notes / deviations

- Producer detail still performs its own `producersApi.getMemberships` call, which is Reviewer/Editor/Admin-only on the server. The section is only rendered for those roles (`canManageProducers` was already role-gated before `can_edit` existed), so owners/managers who are plain Readers will not see the Linked Users list. Showing the member list to members would require relaxing that endpoint; it is out of scope for this issue.
- No Follow/Unfollow controls were added anywhere.
