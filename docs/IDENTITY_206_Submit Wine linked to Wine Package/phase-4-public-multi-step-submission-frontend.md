# Phase 4 — Public Multi-Step Submission Frontend

## Status

Partially implemented on November 14, 2026.

## Objective

Implement the public multi-step submission form: Contact & Company, Wines, Service & Submission Details, Review & Declaration, with validation, Turnstile integration, and confirmation page.

## Dependencies

Phase 0, Phase 1, Phase 2, Phase 3

## Backend Work

- API endpoint from Phase 3 must be deployed and functional
- Turnstile and rate limiting from Phase 4 must be active
- No new backend work in this phase

## Frontend Work

### Frontend Work

1. **Multi-Step Form Structure**
   - Route: `/trade/submit` with steps as sub-routes or state
   - Progress indicator (step 1 of 4, etc.)
   - Navigation: Next, Back, Submit (final step)
   - Draft state persistence (localStorage or sessionStorage)
   - Clear draft on successful submission

2. **Step 1 — Contact and Company**
   - Fields: company_name (required), contact_name (required), email (required, valid format), phone, address, country (required), website, role (select: winery/importer/distributor/agent/other), notes
   - Client-side validation: required fields, email format, website URL format
   - Server-side error display (field-level)
   - Honeypot field (hidden)

3. **Step 2 — Wines**
   - Dynamic list: add/remove wines (minimum 1, reasonable max e.g., 20)
   - Per wine fields: wine_name (required), vintage (required, year), region, appellation, grape_varieties, abv (number, 0-100), volume_ml (select: 375, 500, 750, 1000, 1500, other), closure_type (select), tasting_notes, technical_sheet_url (URL), trade_price (decimal), retail_price (decimal), sample_available (boolean), sample_quantity (number, if sample_available)
   - Client-side validation per wine
   - Server-side error display per wine
   - Duplicate wine detection (same name + vintage)

4. **Step 3 — Service and Submission Details**
   - Service type (select: review, listing, both)
   - Additional requests/information
   - Declaration checkboxes (required): authority to submit, samples provided if requested, information accurate, agree to terms and fees
   - Turnstile widget rendered here (before final step)

5. **Step 4 — Review and Declaration**
   - Read-only summary of all entered data
   - Edit links to return to previous steps
   - Final declaration checkbox
   - Submit button (disabled until Turnstile token received)
   - Prevent duplicate clicks (loading state, disable button)

6. **Confirmation Page**
   - Route: `/trade/submit/confirmation/:reference`
   - Displays: package reference, guest access link, next steps, contact email for questions
   - Copy-to-clipboard for reference
   - No sensitive data exposed

7. **Form State Management**
   - React Hook Form or similar
   - Validation schema (Zod/Yup)
   - Step-specific validation
   - Cross-step validation on review step

8. **Accessibility and Mobile**
   - Mobile-first responsive
   - Keyboard navigation between steps
   - Screen reader announcements for step changes
   - Focus management
   - Large touch targets

9. **Error Handling**
   - Field-level server errors
   - Global error banner for network/500 errors
   - Turnstile error states
   - Rate limit 429 handling with retry guidance

## Database and Migration Work

- No database changes in this phase

## API and Authorization Requirements

- Reuse existing authentication and role policies
- Public endpoints narrowly scoped
- Object-level authorization for package access
- Editor/Admin explicit policies for assessment/commercial actions
- Internal notes staff-only
- Guest tokens: single package, scoped permissions, hashed, expiry, revocation
- No auto-login for existing accounts based on email submission

## Security Requirements

- Turnstile token required on submit
- No sensitive data in confirmation page
- Honeypot field included
- No auto-complete on sensitive fields
- CSRF protection via SameSite cookies or token
- XSS prevention in all user-input display

## Testing Requirements

1. **Component Tests** - Each step renders correctly, validation works (client and server error display), add/remove wines, progress indicator updates, navigation between steps preserves data, Turnstile widget renders, submit button disabled until Turnstile ready, duplicate click prevention, confirmation page displays correctly
2. **Integration Tests** - Full form submission with valid data, form submission with server validation errors, form submission with network error, Turnstile failure handling, rate limit 429 handling, draft persistence and restoration, mobile layout
3. **Accessibility Tests** - Keyboard navigation, screen reader announcements, focus management, color contrast, form labels and descriptions

## Deployment/Configuration Requirements

- Frontend env: VITE_TURNSTILE_SITE_KEY, VITE_API_BASE_URL
- API endpoint from Phase 3 deployed
- Turnstile/rate limiting from Phase 4 active
- Rebuild frontend after env changes

## AI Implementation Prompt

```
Implement the public multi-step wine submission form for the Wine Words Trade portal.

Requirements:
- 4-step form: Contact & Company, Wines, Service & Details, Review & Declaration
- Dynamic wine list (add/remove, min 1)
- Client-side validation with server error display
- Turnstile widget on step 3/4
- Duplicate click prevention
- Draft state persistence
- Confirmation page with package reference and guest link
- Mobile-first responsive design
- Full accessibility (WCAG 2.1 AA)
- Honeypot field
- Rate limit / Turnstile error handling

Deliver:
- Form components for each step
- Form state management (React Hook Form + Zod)
- Validation schemas
- Turnstile integration component
- Confirmation page
- Component tests for all steps
- Integration tests for full flow
- Accessibility audit
```

## Acceptance Criteria

- [ ] Anonymous submitter can complete and submit valid package
- [ ] All 4 steps render and navigate correctly
- [ ] Client validation works on each step
- [ ] Server validation errors display at field level
- [ ] Multiple wines can be added/removed
- [ ] Turnstile widget renders and token submitted
- [ ] Duplicate clicks prevented
- [ ] Draft state persists across navigation
- [ ] Confirmation page shows reference and guest link
- [ ] Mobile responsive layout works
- [ ] Accessibility checks pass
- [ ] Component and integration tests pass

## Exit Gate

- An anonymous submitter can complete and submit a valid package through the responsive frontend
- All validation, Turnstile, and error handling works
- Tests pass

## Implementation Notes

- No shipping collection during initial submission (per product decisions)
- Shipping information collected after package acceptance/payment (Phase 13)
- Form should reuse existing Wine Words UI components where possible
- Technical sheet URL should be validated as URL
- Prices should accept decimal with 2 places

## Validation Results

- Commands executed: `cd /Users/romalopes/Documents/studies/my_project/wine_project/wine_words && npm run build`
- Result: passed.
- Implemented: four-step responsive form at `/trade/submit`, contact and wine validation, dynamic wines, duplicate detection, local draft persistence, idempotency-key submission, confirmation with guest link, copy action, loading/error states.
- Not implemented: Cloudflare Turnstile widget/token submission, honeypot field, dedicated confirmation URL `/trade/submit/confirmation/:reference`, schema-library validation, and automated component/integration/accessibility tests.
- Unresolved issues: The API currently accepts the implemented payload without Turnstile because Turnstile is a separate platform plan; production launch must not treat this frontend state as complete until server verification is active. Repository-wide `npm run typecheck` remains red on unrelated pre-existing files; no Trade-specific TypeScript errors remain after the follow-up check.
