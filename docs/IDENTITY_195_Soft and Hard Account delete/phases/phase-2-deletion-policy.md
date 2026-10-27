# Phase 2 — Deletion Policy & Dependency Report

**Status:** ✅ Complete · **File:** `app/services/deletion_policy.rb`

## Design

`DeletionPolicy` is a fail-closed policy object: it returns a structured report and
**blocks** on any association that cannot be verified as safe.

```json
{
  "hard_delete_allowed": false,
  "blocking_reasons": [
    { "code": "billing_customers", "count": 1,
      "message": "1 billing record authored by this user" }
  ],
  "disposable_counts": { "likes": 5, "follows": 8, "notifications": 2,
                         "user_roles": 2, "user_identities": 0,
                         "user_subscriptions": 1 }
}
```

## Blocking rules (hard delete refused)

| Code | Trigger | Rationale (plan §2) |
|---|---|---|
| `published_reviews` | any `Review` row | published content protected |
| `comments` | any `Comment` row | plan: comments block initially |
| `articles` | any `Article` row (`Article.where(user_id:)` — User has no `has_many :articles`) | published/draft content protected |
| `producer_memberships` | any `ProducerMembership` | reassign/revoke explicitly first |
| `subscription_changes` | any `SubscriptionChange` | financial/billing history |
| `billing_customers` | any `BillingCustomer` | financial records |
| `last_admin` | target is Admin **and** no other admin exists | avoid administrative lockout |

The last-admin check counts admins **excluding the target**, so an admin may remove a
colleague while at least one other admin remains.

## Disposable set (cleaned, does not block)

`likes`, `follows`, `notifications`, `user_roles`, `user_identities`,
`user_subscriptions` — each reported with a count for the admin preview.

## Fail-closed behaviour

Anything not in the blocking/disposable list is simply not cleaned. New associations
default to *blocking-by-omission*: if a future model references `users` without being
classified here, hard delete will not silently cascade into it (the policy does not use
a generic `associations.empty?` test).

## Test evidence

`spec/services/account_deletion_service_spec.rb` — blocked cases return
`blocking_reasons` including `billing_customers` and `last_admin`.