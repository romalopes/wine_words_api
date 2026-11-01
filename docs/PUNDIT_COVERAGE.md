# API authorization coverage

This document records the authorization boundary after the pre-permission-system
stabilization pass. Policies still use the existing `User` role helpers; no
database-backed permission resolver is active yet.

## Pundit-enforced resource families

- Wines, vintages, grapes, producers, countries, regions, categories, taste
  parameters, reviews, and articles.
- Images, delegated to the imageable record's update policy.
- Article projects and nested notebooks, including ownership scopes and linked
  record validation.
- Wine packages, nested items, shipment tracking, workflow actions, and package
  scopes.
- Subscriptions, producer memberships, account invitations, and user
  administration.
- Analytics reporting, diagnostics, configuration, logs, health diagnostics,
  and impersonation administration.

Administrative policies are evaluated against `real_current_user` so an admin
does not gain or lose administrative authority by impersonating another user.
Ordinary content policies use the effective `current_user`.

## Intentional non-Pundit boundaries

These endpoints use authentication, cryptographic integrity, rate limiting, or
feature-state checks rather than record authorization:

- Devise sessions, registration, and password recovery.
- Public invitation validation/acceptance and email-verification links.
- Social authentication and authentication-identity credential verification.
- Public analytics event ingestion.
- Stripe webhook signature verification.
- The private test-access password/token gate.
- Feature/configuration guards such as analytics diagnostics being enabled and
  hard deletion being enabled. Pundit authorization runs before these guards.

## Remaining role predicates that are not primary authorization gates

- Article/review show actions retain explicit draft concealment to return 404
  rather than 403 before policy authorization.
- Article-project lookup relations narrow Reviewer results to their own authored
  articles/reviews; linked records are independently authorized by Pundit.
- User detail serialization includes another user's account profile only for the
  real Admin actor after the endpoint itself has been authorized.

## Future permission-system cutover

The future resolver should replace role-helper internals inside policies and
policy scopes one resource family at a time. Controllers should continue to call
`authorize`/`policy_scope`; they should not call the resolver directly.