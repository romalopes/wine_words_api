# Phase 9 — Notifications and Email Integration

## Status

Planned. No implementation started.

## Objective

Implement all required email templates, in-app notifications, and delivery behavior for the Trade portal.

## Dependencies

Phase 0, Phase 1, Phase 3, Phase 5, Phase 6, Phase 7, Phase 8

## Backend Work

### Backend Work

1. **Notification Service — REUSE existing system**
   - Extend the existing Wine Words notification/mail infrastructure (mailers, ActiveJob, notification records)
   - Recipient resolution: submitter (package owner or guest-token contact), editors, admins
   - All delivery async via ActiveJob

2. **Required Email Templates (~14)**
   - Email verification (new submitter)
   - Password setup (new submitter)
   - Package claim link (existing email submitter)
   - Submission confirmation (all submitters)
   - Assessment update (approved / rejected / partial)
   - Information request (editor needs more info)
   - New conversation message (submitter and editor sides)
   - Quote available
   - Invoice sent
   - Payment confirmation
   - Shipping instructions
   - Review assigned
   - Review published
   - Guest token expiry warning

3. **Template structure**
   - Subject, HTML body, text body; variables: package_reference, submitter_name, wine_names, links, dates, amounts
   - Consistent Wine Words branding; unsubscribe footer for marketing only (transactional emails exempt)

4. **Delivery behaviour**
   - Async via ActiveJob; retry with exponential backoff; dead-letter handling for persistent failures
   - Duplicate-delivery prevention (idempotency keys — align with `WinePackageEvent.idempotency_key` where an event drives the email)
   - Bounce/complaint webhook handling; delivery logging/monitoring

5. **In-app notifications**
   - Notification centre for authenticated users; badge count; mark read/archive; deep links to package detail

6. **Integration points**
   - Phase 3: submission confirmation · Phase 5: verification/password/claim · Phase 7: assessment updates, info requests · Phase 8: new messages · Phase 10: quotes, invoices · Phase 11: payment confirmation · Phase 12: shipping instructions · Phase 13: review milestones

## Frontend Work

### Frontend Work

1. **Notification Centre**
   - Header icon with unread badge (authenticated users)
   - Dropdown/list of recent notifications; mark as read; "view all"
   - Navigation links to the relevant package/detail page

2. **Admin Template Previews**
   - Admin page to preview every Trade email template with sample data
   - Test-send to self

## Database and Migration Work

### Database and Migration Work

- Extend the existing notifications table with Trade-specific notification types if needed
- Indexes: `recipient_id`, `read_at`, `created_at`
- No parallel notification store — reuse the existing schema

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

- No sensitive data in email bodies (no passwords, raw tokens, full payment details)
- Links use signed tokens with expiry
- PII not logged in delivery logs
- Bounce/complaint data handled securely
- Unsubscribe mechanism for marketing only — never on transactional emails

## Testing Requirements

### Testing Requirements

1. **Email Tests**
   - Each template renders correctly with variables (HTML + text)
   - Links work and expire correctly; branding consistent; delivery via ActiveJob

2. **Notification Tests**
   - In-app notifications created on all Trade events
   - Badge updates; mark-read works; navigation links correct

3. **Delivery Tests**
   - Retry logic works; duplicate prevention works (same idempotency key never sends twice)
   - Bounce/complaint handling; delivery status logging

## Deployment/Configuration Requirements

### Deployment/Configuration Requirements

- Email templates in version control
- Existing provider (Brevo/Resend/SendGrid) configuration reused
- SPF/DKIM/DMARC verified for the sending domain; from/reply-to addresses configured
- Bounce/complaint webhook endpoints registered
- Delivery monitoring/alerting

## AI Implementation Prompt

```
Implement notifications and email integration for the Wine Words Trade portal.

Requirements:
- ~14 email templates covering all Trade flows (verification, password setup, claim link,
  submission confirmation, assessment update, information request, new message, quote,
  invoice, payment confirmation, shipping instructions, review assigned, review published,
  guest token expiry warning)
- In-app notification centre (badge, list, mark read, deep links)
- Async delivery via ActiveJob with retry, duplicate prevention, bounce/complaint handling
- Integration with every prior phase's events
- Secure token links in emails; consistent branding; no sensitive data in bodies
- Admin template preview + test-send page

Deduplication constraints (from Phase 1):
- REUSE the existing Wine Words mailers, ActiveJob jobs, and notification records — do NOT
  create a parallel notification system
- Where an email is driven by a package event, reuse WinePackageEvent.idempotency_key so the
  event and its email share duplicate-prevention
- Transactional emails (verification, confirmation, etc.) must NOT include unsubscribe links

Deliver:
- Email templates (ERB/Liquid) with HTML and text variants
- Notification service extensions and ActiveJob jobs per type
- In-app notification centre frontend
- Admin template preview page
- Tests for every template and delivery behaviour
- Integration tests proving each phase's events trigger the right notification exactly once
```

## Acceptance Criteria

- [ ] All ~14 templates render correctly (HTML + text)
- [ ] Submission confirmation sent on Phase 3 submission
- [ ] Verification/password/claim emails sent on Phase 5 flows
- [ ] Assessment update + information-request emails on Phase 7
- [ ] Message notification emails on Phase 8
- [ ] Quote/invoice emails on Phase 10
- [ ] Payment confirmation on Phase 11
- [ ] Shipping instructions on Phase 12
- [ ] Review milestone emails on Phase 13
- [ ] In-app notifications created for all events; centre functional
- [ ] Async delivery with retry works; duplicates prevented
- [ ] Bounce/complaint handling works
- [ ] No sensitive data in emails; transactional emails have no unsubscribe
- [ ] All tests pass

## Exit Gate

- Notification delivery is observable, retryable, and does not leak private information
- All Trade email flows integrated and provably triggered once per event
- In-app notification centre functional

## Implementation Notes

- Reuse existing Wine Words mailers, ActiveJob, and notification patterns
- Align email idempotency keys with WinePackageEvent idempotency keys where applicable
- Email domain setup (SPF/DKIM/DMARC) must be verified before production launch

## Validation Results

*To be completed during execution*

- Commands executed:
- Tests run:
- Failures:
- Unresolved issues:
