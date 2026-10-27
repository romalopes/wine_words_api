# Wine Words — Account Lifecycle Dependency Inventory (Phase 0)

**Issue:** IDENTITY_195 · **Date:** 2026-10-26 · **Status:** Verified against `db/schema.rb` and `app/models/*`

## 1. Principal model

The authoritative account principal is **`User`** (`app/models/user.rb`). `Account` is a
profile child (`belongs_to :user`, unique `user_id`) holding names/phone/DOB/address.
Lifecycle state (soft deletion) lives on `User` only — `deleted_at` on `users` — so state
is never duplicated across models.

## 2. Authentication & identity

| Concern | Mechanism | Deletion relevance |
|---|---|---|
| Password auth | Devise (`database_authenticatable`) | Deleted users rejected server-side (`ApplicationController#reject_deleted_user!`) |
| API tokens | `devise-jwt` + `JwtDenylist` (exact-jti denylist) | Token presented at deletion is denylisted; broader enforcement is the request guard |
| Social identities | `UserIdentity` (`belongs_to :user`, dependent destroy) | Disposable — removed with the user |
| Email uniqueness | unique index on `users.email` | Soft-deleted user still occupies the email; re-registration is intentionally **blocked** until hard delete or email release (documented, not silently rewritten) |

## 3. Foreign-key / association inventory

Classification legend: **BLOCKING** (prevents hard delete) · **DISPOSABLE** (safe to
clean on hard delete) · **RETAIN-SEPARATELY** (kept for audit/history, FK nullified by
DB) · **REVIEW** (needs a product decision before any automated cleanup).

| Model / table | FK | `dependent:` today | Classification | Cleanup on hard delete |
|---|---|---|---|---|
| `Account` (`accounts`) | `accounts.user_id` (unique, NOT NULL) | `dependent: :destroy` on User | **DISPOSABLE** | destroyed with user inside transaction |
| `Review` (`reviews`) | `reviews.user_id` NOT NULL, FK no-action | `dependent: :destroy` on User | **BLOCKING** | hard delete refused; rows preserved |
| `Article` (`articles`) | `articles.user_id` NOT NULL, FK no-action | *(inverse only — no `has_many :articles` on User)* | **BLOCKING** | counted via `Article.where(user_id:)`; hard delete refused |
| `Comment` (`comments`) | `comments.user_id` NOT NULL (+ polymorphic `commentable`) | `dependent: :destroy` on User | **BLOCKING** (per plan: comments block initially) | hard delete refused |
| `Like` (`likes`) | `likes.user_id` NOT NULL | `dependent: :destroy` on User | **DISPOSABLE** | `destroy_all` in transaction |
| `Follow` (`follows`) | `follows.user_id`, FK **ON DELETE CASCADE** | `dependent: :destroy` on User | **DISPOSABLE** | `destroy_all` |
| `Notification` (`notifications`) | `recipient_id` (no-action FK), `actor_id` **ON DELETE NULLIFY** | `dependent: :destroy` on User | **DISPOSABLE** | `destroy_all` |
| `NotificationPreference` | `user_id` unique, FK **ON DELETE CASCADE** | `dependent: :destroy` | **DISPOSABLE** | destroyed |
| `UserRole` (`user_roles`) | `user_id` | `dependent: :destroy` | **DISPOSABLE** | `destroy_all` (roles themselves kept) |
| `UserIdentity` (`user_identities`) | `user_id` NOT NULL | `dependent: :destroy` | **DISPOSABLE** | `destroy_all` |
| `UserSubscription` (`user_subscriptions`) | `user_id` NOT NULL, `subscription_id` NOT NULL | `dependent: :destroy` | **DISPOSABLE** | `destroy_all` (plans kept) |
| `SubscriptionChange` (`subscription_changes`) | `user_id` NOT NULL | `dependent: :restrict_with_error` on User | **BLOCKING** | already restricts; also surfaced by policy |
| `BillingCustomer` (`billing_customers`) | `user_id` NOT NULL | `dependent: :destroy` | **BLOCKING** (financial record) | hard delete refused |
| `ProducerMembership` | `user_id` NOT NULL, `created_by_id` **ON DELETE NULLIFY** | `dependent: :destroy` on User | **BLOCKING** (producer responsibility) | hard delete refused |
| `WinePackage` | `reviewer_id` / `created_by_id` / `accepted_by_id` / `rejected_by_id`, all **ON DELETE NULLIFY** | `dependent: :nullify` on User | **RETAIN-SEPARATELY** | package rows kept, user refs nullified by DB |
| `ArticleProject` | `created_by_id` **ON DELETE NULLIFY** | `dependent: :nullify` on User | **RETAIN-SEPARATELY** | kept, FK nullified |
| `Log` / `LogObject` (audit) | `logs.user_id` (optional), `impersonated_user_id` (optional) | none (audit rows) | **RETAIN-SEPARATELY** | kept — audit trail survives deletion |
| `Analytics::Event` | identity string (anonymised separately, issue #172) | after_destroy purge hooks on content | **REVIEW** | content-driven; account deletion does not touch events |

## 4. Last-admin protection

Admins are `User.joins(:roles).where(roles: { name: "Admin" })` (`Role` is a string-backed
enum). The policy blocks hard delete when **no other admin** would remain
(`admin_count_excluding_user.zero?`), avoiding administrative lockout while still
allowing an admin to remove a colleague.

## 5. External / non-Postgres data (out of DB scope)

* **Active Storage** blobs/attachments (producer logos, review/article images) — live on
  object storage; attachment rows cascade with their owners.
* **Stripe** — `BillingCustomer`/`SubscriptionBillingPrice` mirror provider state; the
  plan requires resolving billing before deletion (hence the BLOCKING classification).
* **Email provider, logs on disk, backups** — not erased by DB deletion; hard delete
  makes no full-erasure claim (per plan §6).