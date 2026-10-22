# Phase 0: Repository Audit

## Summary
Verified existing codebase structure and established project decisions before implementation.

## Key Findings

### API (Rails)
- **User model** (`app/models/user.rb`): Has roles (`admin?`, `editor?`, `reviewer?`, `wine_manager?`), subscription associations, and analytics_opt_out
- **Producer model** (`app/models/producer.rb`): Standard producer attributes with regions, grapes, wines, images
- **Authentication**: JWT-based with `current_user` in `ApplicationController`
- **Authorization**:
  - `/users` endpoints: **Admin-only** (not Admin/Editor as originally assumed)
  - `/producers` mutations: Guarded by `ensure_wine_manager` (Admin/Editor/Reviewer)
  - No existing user-producer membership system

### Frontend (React + TypeScript)
- **UserRoles.tsx**: `/users` page with search, role assignment, subscription assignment, impersonation
- **AccountSettings.tsx**: `/account` page with profile, password, social auth, analytics opt-out, **already has "My Producers" section**
- **ProducerForm.tsx**: Shared edit form at `/producers/:slug/edit` (used by wine managers)
- **Routes**: `/users` (UserRoles), `/account` (AccountSettings), `/producers/:slug/edit` (ProducerForm)

### Existing Types
- `AdminUser`, `RoleOption`, `Subscription` in `src/types/user.ts`
- `Producer`, `ProducerSearchResult` in `src/types/producer.ts`

## Verified Decisions
1. **Membership principal**: `User` (not `Account`)
2. **Admin-only** for `/users` directory and membership management
3. **Producer edit access**: Wine managers (Admin/Editor/Reviewer) retain full access; linked users get edit-only access to their producers
4. **Membership does NOT grant global role** — only links user to specific producers
5. **Frontend**: Convert `/users` rows to links → `/users/:id`; keep role/subscription controls on detail page; add membership management

---

*Completed: 2026-10-22*