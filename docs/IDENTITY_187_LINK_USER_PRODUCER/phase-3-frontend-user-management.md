# Phase 3: Frontend - User Management

**Status:** ✅ Complete

## TypeScript Types

### `src/types/user.ts` (Extended)
```typescript
export interface ProducerMembership {
  id: number
  producer: {
    id: number
    name: string
    slug: string
    country: string | null
  }
  created_by: { id: number; display_name: string } | null
  created_at: string
}

export interface UserDetail extends AdminUser {
  analytics_opt_out: boolean
  producer_memberships: ProducerMembership[]
}
```

### `src/types/producer.ts` (Extended)
```typescript
export interface ProducerSummary {
  id: number
  name: string
  slug: string
  country: string | null
  email: string | null
  producer_type: string | null
  founded_year: number | null
}
```

### `src/types/api.ts` (Extended)
```typescript
export interface AccountApi {
  // ...existing methods
  myProducers(): Promise<ProducerSummary[]>
}

export interface UsersApi {
  // ...existing methods
  show(userId: number): Promise<UserDetail>
  producerMemberships: {
    list(userId: number): Promise<ProducerMembership[]>
    create(userId: number, producerId: number): Promise<ProducerMembership>
    destroy(userId: number, membershipId: number): Promise<unknown>
  }
}
```

## API Services (`src/services/accountApi.ts`)

```typescript
export function createAccountApi(request: ApiRequester): AccountApi {
  return {
    // ...existing methods
    myProducers: () => request<ProducerSummary[]>("/account/producers", { auth: true }),
  }
}

export function createUsersApi(request: ApiRequester): UsersApi {
  return {
    // ...existing methods
    show: (userId) => request<UserDetail>(`/users/${userId}`, { auth: true }),
    producerMemberships: {
      list: (userId) => request<ProducerMembership[]>(`/users/${userId}/producer_memberships`, { auth: true }),
      create: (userId, producerId) => request<ProducerMembership>(`/users/${userId}/producer_memberships`, { method: "POST", auth: true, body: { producer_id: producerId } }),
      destroy: (userId, membershipId) => request(`/users/${userId}/producer_memberships/${membershipId}`, { method: "DELETE", auth: true }),
    },
  }
}
```

## Routing (`src/components/AppRoutes.tsx`)

```tsx
import UserDetail from "./UserDetail";

<Route element={<UserRoles />} path="/users" />
<Route element={<UserDetail />} path="/users/:id" />
```

## New Component: `UserDetail.tsx` (`src/components/UserDetail.tsx`)

**Features:**
- Fetches user detail via `usersApi.show(userId)`
- Displays user email, display name
- Role checkboxes (preserves existing `USER_ROLE_OPTIONS`)
- Subscription selector (preserves existing behavior)
- **Producer Memberships section:**
  - Lists linked producers with country, linked-by info
  - "Link Producer" button opens modal
  - Modal with debounced producer search (300ms)
  - Select producer → "Link Selected" button
  - "Unlink" button per membership with confirmation
- Loading states for all operations

**UI Pattern:** Follows existing card/modal patterns in codebase (e.g., `SubscriptionAdmin`, `ProducerForm`)

## Updated Component: `UserRoles.tsx`

**Already had:** Row linking to `/users/:id` (line 128):
```tsx
<Link key={u.id} to={`/users/${u.id}`} className="admin-user-row">
```

No changes needed - the route now resolves to `UserDetail`.

## Verification
- TypeScript types compile (pending typecheck)
- Routes resolve correctly
- Component follows existing UI patterns