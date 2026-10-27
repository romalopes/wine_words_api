# Phase 0 — Discovery & Dependency Inventory

**Status:** ✅ Complete · **Deliverable:** [`../dependency_inventory.md`](../dependency_inventory.md)

## What was done

1. Audited every `User`-referencing table in `db/schema.rb`: `accounts`, `articles`,
   `billing_customers`, `comments`, `follows`, `likes`, `logs`, `notification_preferences`,
   `notifications`, `producer_memberships`, `reviews`, `subscription_changes`,
   `user_identities`, `user_roles`, `user_subscriptions`, plus the nullable-author columns
   on `wine_packages` / `article_projects`.
2. Audited every `belongs_to :user` / `dependent:` option in `app/models/*`.
3. Classified each dependency: **BLOCKING** (reviews, articles, comments,
   producer memberships, subscription changes, billing customers), **DISPOSABLE**
   (likes, follows, notifications, preferences, user roles, identities,
   user subscriptions, account), **RETAIN-SEPARATELY** (wine-package /
   article-project authorship via ON DELETE NULLIFY, audit logs), **REVIEW**
   (analytics events).
4. Identified the principal: **`User`** is authoritative; `Account` is a profile child.
5. Documented auth surface: Devise + `devise-jwt` (`JwtDenylist`, exact-jti), social
   identities (`UserIdentity`), unique-email constraint behaviour after soft delete.
6. Last-admin protection mechanism designed around `Role` string-backed enum.

## Decisions

* No behaviour changed in Phase 0 (plan requirement).
* Email re-registration after soft delete is **blocked**, not silently rewritten —
  privacy/account-recovery policy decision deferred to the product owner.

## Phase 1–5 checkpoints feeding forward

The inventory directly drives `DeletionPolicy` (Phase 2) and the cleanup list inside
`AccountDeletionService#transaction_hard_delete!` (Phase 3).