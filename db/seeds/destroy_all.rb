# frozen_string_literal: true

# ============================================================================
# DESTROY ALL DATA — Wine Words API
# ============================================================================
#
# Purpose:
#   Destroys every application data row from the database, in the exact
#   reverse order of the foreign-key graph defined in `db/schema.rb`, so
#   referential integrity is preserved (children/referencing tables are
#   deleted before the parents they point to).
#
# What is destroyed:
#   - All application data tables (catalogue, content, users, roles,
#     subscriptions, accounts, articles, reviews, wine packages, profiles,
#     active storage attachments/blobs, etc.)
#
# What is NOT touched:
#   - Rails infrastructure tables (solid_queue_*, solid_cable_messages,
#     solid_cache_entries) — managed by Solid Queue/Cable/Cache, not app data.
#   - `ar_internal_metadata` / `schema_migrations` — migration bookkeeping.
#   - The schema itself (tables, indexes, sequences are kept; only rows go).
#
# How to run:
#   Because this is destructive, it refuses to run unless you confirm:
#
#     CONFIRM=DESTROY bin/rails runner db/seeds/destroy_all.rb
#
# After running, re-seed with:
#   bin/rails db:seed
#   bin/rails runner db/seeds/reset_pk_sequences.rb
#
# ============================================================================

conn = ActiveRecord::Base.connection

# Safety guard: never run accidentally.
unless ENV["CONFIRM"] == "DESTROY"
  abort <<~MSG
    This seed DESTROYS ALL DATA in #{conn.current_database.inspect} (#{Rails.env}).

    If you are sure, run it with explicit confirmation:

      CONFIRM=DESTROY bin/rails runner db/seeds/destroy_all.rb
  MSG
end

puts "== Destroying all data in #{conn.current_database.inspect} (#{Rails.env}) =="

# Tables that reference themselves (e.g. comments.parent_id -> comments,
# regions.parent_id -> regions). A single DELETE can violate the immediate
# self-FK depending on row scan order, so these are deleted in repeated
# passes until empty.
SELF_REFERENCING_TABLES = %w[
  comments
  regions
].freeze

# Deletion order: reverse topological order of `db/schema.rb` foreign keys.
# Every child table (left side of `add_foreign_key`) appears before every
# parent table it references (right side). Grouped for readability; the order
# within/between groups is FK-safe.
TABLES_IN_DESTRUCTION_ORDER = [
  # -- 1. Standalone app data (no inbound FKs from other tables) ------------
  "analytics_events",            # no FK dependencies
  "app_settings",                # no FK dependencies

  # -- 2. Active Storage (attachments/variants before their blobs) ----------
  "active_storage_variant_records", # -> active_storage_blobs
  "active_storage_attachments",     # -> active_storage_blobs

  # -- 3. Logs & notifications ----------------------------------------------
  "log_objects",                 # -> logs
  "logs",                        # -> users
  "notifications",               # -> users, wine_packages

  # -- 4. Articles / projects / content join tables --------------------------
  "article_project_notebooks",   # -> article_project_vintages
  "article_reviews",             # -> articles, reviews
  "article_project_reviews",     # -> article_projects, reviews
  "article_categories",          # -> articles, categories
  "article_producers",           # -> articles, producers
  "article_tags",                # -> articles, tags
  "article_vintages",            # -> articles, vintages
  "article_project_producers",   # -> article_projects, producers
  "article_project_vintages",    # -> article_projects, vintages
  "article_projects",            # -> articles, users
  "review_categories",           # -> categories, reviews

  # -- 5. Shipping & wine packages -------------------------------------------
  "shipment_tracking_events",    # -> wine_packages
  "wine_package_items",          # -> reviews, vintages, wine_packages
  "shipment_trackings",          # -> wine_packages

  # -- 6. Subscription bookkeeping (before users & subscriptions) ------------
  "subscription_changes",        # -> user_subscriptions, users
  "subscription_billing_prices", # -> subscriptions
  "subscription_subscription_features", # -> subscription_features, subscriptions
  "user_identities",             # -> users
  "user_roles",                  # -> roles, users
  "user_subscriptions",          # -> subscriptions, users

  # -- 7. Accounts & billing ---------------------------------------------------
  "account_addresses",           # -> accounts, countries
  "accounts",                    # -> users
  "addresses",                   # -> countries, producers
  "billing_customers",           # -> users
  "billing_events",              # -> users (Stripe event log)

  # -- 8. Engagement ------------------------------------------------------------
  "comments",                    # -> comments (self), users
  "likes",                       # -> users

  # -- 9. Wine profiles & wine join tables ----------------------------------
  "wine_profile_taste_parameters", # -> taste_parameters, wine_profiles
  "wine_profile_grapes",           # -> wine_profiles, grapes (columns, no declared FK)
  "wine_profile_regions",          # -> wine_profiles, regions (columns, no declared FK)
  "wine_profiles",                 # -> (referenced only by the tables above)
  "wine_categories",               # -> categories, wines
  "wine_grapes",                   # -> grapes, wines
  "wine_regions",                  # -> regions, wines
  "wine_taste_parameters",         # -> taste_parameters, wines

  # -- 10. Wine packages -----------------------------------------------------
  "wine_packages",                 # -> producers, users (x4)

  # -- 11. Catalogue core ----------------------------------------------------
  "reviews",                       # -> categories, users, vintages
  "articles",                      # -> categories, users
  "vintages",                      # -> wines
  "wines",                         # -> categories, producers

  # -- 12. Producers ----------------------------------------------------------
  "producer_grapes",               # -> grapes, producers
  "producer_memberships",          # -> producers, users (x2)
  "producer_regions",              # -> producers, regions
  "producers",                     # -> (referenced by addresses, wines, packages, joins)

  # -- 13. Users, subscriptions & roles --------------------------------------
  "account_invitations",           # -> users
  "users",                         # -> subscriptions (and referenced by 13+ tables above)
  "subscriptions",                 # -> (referenced by users, user_subscriptions, prices, features)
  "subscription_features",         # -> (referenced by subscription_subscription_features)
  "roles",                         # -> (referenced by user_roles)

  # -- 14. Taxonomies ---------------------------------------------------------
  "tags",                          # -> (referenced by article_tags)
  "categories",                    # -> (referenced by articles, reviews, wine_categories, joins)
  "taste_parameters",              # -> (referenced by wine taste parameter joins)

  # -- 15. Grape Regions ---------------------------------------------------------
  "grape_regions",                          # -> (referenced by grape_regions)


  # -- 16. Geography & grapes -------------------------------------------------
  "grapes",                        # -> countries (and referenced by wine_grapes, producer_grapes)
  "regions",                       # -> countries, regions (self)
  "countries",                     # -> (referenced by account_addresses, addresses, grapes, regions)

  # -- 17. Auth bookkeeping, images & blobs -----------------------------------
  "jwt_denylists",                 # no FK dependencies
  "images",                        # polymorphic (no declared FK)
  "active_storage_blobs"           # -> (referenced by variant_records & attachments)
].freeze

total_deleted = 0

conn.transaction do
  TABLES_IN_DESTRUCTION_ORDER.each do |table|
    unless conn.table_exists?(table)
      puts "  - #{table}: skipped (table does not exist)"
      next
    end

    quoted = conn.quote_table_name(table)
    table_total = 0

    if SELF_REFERENCING_TABLES.include?(table)
      # Delete in repeated passes so self-referencing rows (children pointing
      # at parents in the same table) never violate their own FK.
      passes = 0
      loop do
        deleted = conn.delete("DELETE FROM #{quoted}")
        table_total += deleted
        passes += 1
        break if deleted.zero? || passes > 50
      end
    else
      table_total += conn.delete("DELETE FROM #{quoted}")
    end

    total_deleted += table_total
    puts "  - #{table}: #{table_total} rows deleted"
  end
end

puts "== Done: #{total_deleted} rows deleted across #{TABLES_IN_DESTRUCTION_ORDER.size} tables =="

if total_deleted.positive?
  puts <<~REMINDER

    Next steps:
      1. Re-seed:        bin/rails db:seed
      2. Reset PKs:      bin/rails runner db/seeds/reset_pk_sequences.rb
  REMINDER
end
