# Phase 0: Repository Audit

**Status:** ✅ Complete

## Summary

This phase documented the existing codebase structure and verified assumptions before implementation.

## Key Findings

### API (Rails)

- **User Model** (`app/models/user.rb`): Core authentication principal with roles, subscriptions, and wine manager permissions
- **Producer Model** (`app/models/producer.rb`): Wine producer entity with regions, grapes, wines, and images
- **User Roles**: `Admin`, `Editor`, `Reviewer` (via `User#wine_manager?`)
- **Routes** (`config/routes.rb`):
  - `GET /api/v1/users/search` - Admin only
  - `PATCH /api/v1/users/:id/assign_roles` - Admin only
  - `PATCH /api/v1/users/:id/assign_subscription` - Admin only
  - `GET /api/v1/account` - Current user profile
  - `GET /api/v1/producers` - Public list
  - `PATCH /api/v1/producers/:id` - `wine_manager?` required
  - `POST /api/v1/producers/:id/logo` - `wine_manager?` required
  - `DELETE /api/v1/producers/:id/logo` - `wine_manager?` required

### Frontend (React + TypeScript)

- **UserRoles** (`src/components/UserRoles.tsx`): Admin user directory at `/users` - already links rows to `/users/:id`
- **AccountSettings** (`src/components/AccountSettings.tsx`): User account at `/account` - already has "My Producers" section using `accountApi.myProducers()`
- **ProducerForm** (`src/components/ProducerForm.tsx`): Shared edit form at `/producers/:slug/edit`
- **Types**: `AdminUser`, `RoleOption`, `Subscription` in `src/types/user.ts`, `Producer` in `src/types/producer.ts`
- **Services**: `usersApi`, `accountApi` in `src/services/accountApi.ts`

## Verified Decisions (Deviations from Original Plan)

| Original Plan Assumption | Verified Reality | Decision |
|--------------------------|------------------|----------|
| `/users` accessible to Admin/Editor | **Admin only** (verified in routes + controller) | Preserve Admin-only |
| Producer mutations via `wine_manager?` | Confirmed: `Admin`, `Editor`, `Reviewer` | Preserve existing, add linked-user edit |
| Membership grants global role | Not implemented | **No** - membership is producer-specific only |
| New `/account/producers` endpoint | Already exists in frontend, needs backend | Implement backend endpoint |

## Files Modified in This Phase
- None (audit only)

## Implementation Progress Summary

After audit, the implementation was completed in the following phases:

- **Phase 1**: Schema & Models ✅
- **Phase 2**: API & Authorization ✅
- **Phase 3**: Frontend User Management ✅
- **Phase 4**: Account Producers ✅
- **Phase 5**: Verification & Rollout ✅