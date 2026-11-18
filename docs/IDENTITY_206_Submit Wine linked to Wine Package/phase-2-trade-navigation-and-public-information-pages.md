# Phase 2 — Trade Navigation and Public Information Pages

## Status

Partially implemented on November 14, 2026.

## Objective

Implement the responsive Trade navigation menu and public information pages (Submit Wines, My Wine Packages, Submission Guidelines, Trade Membership, Promotional Opportunities).

## Dependencies

Phase 0, Phase 1

## Backend Work

### Backend Work

1. **API Endpoints for Public Pages**
   - `GET /api/v1/trade/guidelines` - Submission guidelines content
   - `GET /api/v1/trade/membership` - Trade membership info (placeholder or real)
   - `GET /api/v1/trade/promotional` - Promotional opportunities (placeholder)
   - Content served from CMS or static configuration

2. **No Database Changes**
   - This phase is frontend-focused
   - Backend serves static content or simple CMS-driven pages

## Frontend Work

### Frontend Work

1. **Trade Navigation Menu**
   - Add Trade menu to main header (desktop and mobile)
   - Menu items: Submit Wines → `/trade/submit`, My Wine Packages → `/trade/my-packages` (auth required), Submission Guidelines → `/trade/guidelines`, Trade Membership → `/trade/membership`, Promotional Opportunities → `/trade/promotional`
   - Responsive: hamburger menu on mobile, horizontal on desktop
   - Active state highlighting
   - Accessible markup (ARIA labels, keyboard navigation)

2. **Public Pages**
   - **Submit Wines** (`/trade/submit`): Landing page with CTA to start submission, brief overview, link to guidelines
   - **Submission Guidelines** (`/trade/guidelines`): Eligibility, required details, sample requirements, fees, shipping, review process, FAQ
   - **Trade Membership** (`/trade/membership`): Link to existing membership/pricing or future scope notice
   - **Promotional Opportunities** (`/trade/promotional`): Future scope notice

3. **My Wine Packages Entry Point**
   - `/trade/my-packages` redirects to login if unauthenticated
   - After login/claim, shows package list (Phase 7 implementation)

4. **Styling and UX**
   - Consistent Wine Words design system
   - Mobile-first responsive design
   - SEO meta tags for public pages
   - Accessibility (WCAG 2.1 AA)

## Database and Migration Work

- No database changes required for this phase

## API and Authorization Requirements

- Reuse existing authentication and role policies
- Public endpoints narrowly scoped
- Object-level authorization for package access
- Editor/Admin explicit policies for assessment/commercial actions
- Internal notes staff-only
- Guest tokens: single package, scoped permissions, hashed, expiry, revocation
- No auto-login for existing accounts based on email submission

## Security Requirements

- Public pages must not expose any user data
- No authentication required for guidelines, membership, promotional pages
- My Wine Packages requires authentication (handled by auth middleware)
- Rate limiting on public page endpoints (basic)

## Testing Requirements

1. **Component Tests** - Trade menu renders correctly on desktop and mobile, menu items navigate to correct routes, active state works, responsive breakpoint behavior
2. **Page Tests** - Guidelines page loads and displays content, Membership page loads, Promotional page loads, Submit Wines landing page loads
3. **Accessibility Tests** - Keyboard navigation, screen reader labels, color contrast, focus management
4. **E2E Tests** - Anonymous user can navigate Trade menu, authenticated user sees My Wine Packages, unauthenticated user redirected to login for My Wine Packages

## Deployment/Configuration Requirements

- No new environment variables
- Frontend rebuild required for new routes
- No backend deployment changes

## AI Implementation Prompt

```
Implement the Trade navigation and public information pages for the Wine Words frontend.

Requirements:
- Add responsive Trade menu to main header with 5 items
- Create public pages: Submit Wines landing, Submission Guidelines, Trade Membership, Promotional Opportunities
- My Wine Packages entry point (redirects to login if needed)
- Mobile-first responsive design
- Accessible markup (ARIA, keyboard navigation)
- Consistent Wine Words styling
- SEO meta tags on public pages

Deliver:
- Trade menu component integrated in header
- 4 new page components with routes
- Responsive CSS
- Component tests for menu and pages
- Accessibility audit
```

## Acceptance Criteria

- [ ] Trade menu appears in header on all pages
- [ ] Menu works on desktop (horizontal) and mobile (hamburger)
- [ ] All 5 menu items navigate to correct routes
- [ ] Submit Wines landing page displays
- [ ] Submission Guidelines page displays content
- [ ] Trade Membership page displays (placeholder or real)
- [ ] Promotional Opportunities page displays (placeholder)
- [ ] My Wine Packages redirects unauthenticated users to login
- [ ] Mobile responsive behavior verified
- [ ] Accessibility checks pass
- [ ] Component tests pass

## Exit Gate

- Public Trade area is reachable and responsive without affecting existing navigation
- All pages render correctly
- Tests pass

## Implementation Notes

- Trade Membership and Promotional Opportunities may be placeholders linking to existing functionality or marked as future scope
- Do not block submission launch on these two items
- Content for Guidelines page should come from CMS or configurable source

## Validation Results

- Commands executed: `cd /Users/romalopes/Documents/studies/my_project/wine_project/wine_words && npm run build`
- Result: passed. Trade submission and authenticated package entry routes compile.
- Implemented: `/trade/submit`, `/trade/my-packages`, `/trade/my-packages/:id`, and `/trade/packages/:token`; header entry links for submission and signed-in packages.
- Not implemented: dedicated Guidelines, Trade Membership, Promotional Opportunities pages and a distinct desktop/mobile Trade dropdown. The current header uses direct entry links.
- Unresolved issues: Turnstile widget integration remains part of the separate platform plan; frontend component and E2E tests for the new Trade navigation are still required.
