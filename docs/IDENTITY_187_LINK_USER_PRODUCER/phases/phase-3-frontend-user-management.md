# Phase 3: Frontend User Management

## Summary
Extended TypeScript types, API services, and created UserDetail component with producer membership management. Updated routing to support `/users/:id`.

## Changes

### Types (`src/types/user.ts`)
Added:
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

### Types (`src/types/producer.ts`)
Added:
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

### API Types (`src/types/api.ts`)
Extended `UsersApi` and `AccountApi`:
```typescript
export interface UsersApi {
  // ... existing ...
  show(userId: number): Promise<UserDetail>
  producerMemberships: {
    list(userId: number): Promise<ProducerMembership[]>
    create(userId: number, producerId: number): Promise<ProducerMembership>
    destroy(userId: number, membershipId: number): Promise<unknown>
  }
}

export interface AccountApi {
  // ... existing ...
  myProducers(): Promise<ProducerSummary[]>
}
```

### Services (`src/services/accountApi.ts`)
Added implementations for new API endpoints.

### Routing (`src/components/AppRoutes.tsx`)
Added:
```tsx
import UserDetail from "./UserDetail";
// ...
<Route element={<UserRoles />} path="/users" />
<Route element={<UserDetail />} path="/users/:id" />
```

### Component: `src/components/UserDetail.tsx`
New component with:
- User detail display (name, email)
- Role checkboxes with save functionality
- Subscription dropdown with save functionality
- Producer memberships list with unlink buttons
- "Link Producer" modal with debounced search
- Uses existing `USER_ROLE_OPTIONS` from constants

### UserRoles Updates
Existing component already wraps rows in `<Link to={`/users/${u.id}`}>` — no changes needed.

---

*Completed: 2026-10-22*