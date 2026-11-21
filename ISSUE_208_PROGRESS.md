# Issue #208: Database Revision - Progress Report

## Completed Work (as of 2026-11-21)

### Phase 1: Critical Constraints & Foreign Keys

#### Missing Foreign Keys (5/5)
- wine_profile_grapes.wine_profile_id -> wine_profiles.id
- wine_profile_grapes.grape_id -> grapes.id
- wine_profile_regions.wine_profile_id -> wine_profiles.id
- wine_profile_regions.region_id -> regions.id
- producers.country_id -> countries.id

#### Missing FK Indexes (4/4)
- notification_events.actor_id -> users.id
- wine_packages.shipping_override_by_id -> users.id
- addresses.country_id -> countries.id
- producers.country_id -> countries.id

#### CHECK Constraints (9/9)
- wine_packages.status IN (17 valid statuses)
- wine_package_items.item_status IN (7 valid statuses)
- subscription_changes.change_type IN (6 valid types)
- reviews.status IN (draft, published, archived)
- articles.status IN (draft, published, archived)
- vintages.price_cents >= 0
- wine_package_items.quantity > 0
- subscription_billing_prices.amount_cents >= 0
- subscription_changes.amount_cents >= 0

#### Partial CHECK Constraint (1)
- users.email - nullable for unclaimed users, required when account_status != 'unclaimed'

### Phase 2: Transaction Coverage (Mostly Complete)

**Fixed (6 files):**
- ArticlesController#create, #update, #add_review - wrapped in transactions
- Billing::ChangeSubscription.confirm - split into 3 transactions, Stripe call outside
- Trade::Messages::Send.call - message + event in transaction
- LogService.log - log + objects in transaction
- Api::V1::Admin::Trade::PackagesController#match_producer, #match_catalogue, #assign_reviewer - wrapped in transactions
- Api::V1::PushSubscriptionsController#create, #destroy - wrapped in transactions

### Phase 4: Temporal Tables / Audit History (wine_packages Complete)

**Created for wine_packages:**
1. History Table: wine_packages_histories with all columns + audit columns (valid_from, valid_to, operation I/U/D, changed_by_id)
2. Trigger Function: audit_wine_packages() handling INSERT/UPDATE (AFTER) and DELETE (BEFORE)
3. Point-in-Time Function: wine_packages_as_of(timestamptz)
4. Model: WinePackagesHistory with associations

### Migrations Consolidated

**23 old migrations → 6 new consolidated migrations:**

| Old Migrations | New Consolidated Migration |
|----------------|----------------------------|
| 5 FK migrations | 20261121121244_add_missing_foreign_keys.rb |
| 4 FK index migrations | 20261121121304_add_missing_foreign_key_indexes.rb |
| 9 CHECK constraint migrations | 20261121121321_add_check_constraints.rb |
| 1 partial CHECK constraint | 20261121121343_add_users_email_partial_check.rb |
| 1 history table + 1 trigger | 20261121121400_create_wine_packages_history_table.rb + 20261121121424_add_wine_packages_history_trigger.rb |

**Total: 23 → 6 migrations**

---

### Technical Improvements

1. **Used `add_check_constraint` with DO blocks** - Conditional creation using `IF NOT EXISTS` via `pg_constraint` checks
2. **Used raw SQL for FK constraints** - `NOT VALID` + `VALIDATE CONSTRAINT` pattern for zero-downtime FK addition
3. **Used `CREATE INDEX IF NOT EXISTS`** - For idempotent index creation
4. **Used DO blocks for temporal tables** - `IF NOT EXISTS` checks for tables and triggers
5. **All constraints use explicit names** - For easier debugging and management

### Test Results

**Core Tests Passing:**
- 72 WinePackage model tests
- 31 WinePackageItem model tests
- 47 WinePackages service tests
- 19 Billing service tests
- 34 Trade request tests
- Articles create request test

**Pre-existing Failures (32 model/service, 11 request):**
- Unrelated to our changes (FK on Wine.producer, analytics, configs, etc.)

### Remaining Work (from Issue #208)

1. **Phase 1**: Additional NOT NULL/UNIQUE constraints from audit
2. **Phase 2**: Transaction coverage for webhooks (handlers already transactional)
3. **Phase 3**: Composite indexes from query analysis
4. **Phase 4**: Temporal tables for 12 remaining critical tables
5. **Phase 5**: Security hardening (PII encryption, grants, RLS, audit log)
6. **Phase 6**: Data type fixes (timestamp -> timestamptz)
7. **Phase 7**: Comprehensive testing