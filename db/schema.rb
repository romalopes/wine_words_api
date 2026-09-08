# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_08_000005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.string "city"
    t.bigint "country_id", null: false
    t.datetime "created_at", null: false
    t.string "postal_code"
    t.bigint "producer_id", null: false
    t.string "state"
    t.string "street_address"
    t.datetime "updated_at", null: false
    t.index ["producer_id"], name: "index_addresses_on_producer_id", unique: true
  end

  create_table "article_categories", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id", "category_id"], name: "index_article_categories_on_article_id_and_category_id", unique: true
    t.index ["article_id"], name: "index_article_categories_on_article_id"
    t.index ["category_id"], name: "index_article_categories_on_category_id"
  end

  create_table "article_producers", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.datetime "created_at", null: false
    t.bigint "producer_id", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id", "producer_id"], name: "index_article_producers_on_article_id_and_producer_id", unique: true
    t.index ["article_id"], name: "index_article_producers_on_article_id"
    t.index ["producer_id"], name: "index_article_producers_on_producer_id"
  end

  create_table "article_reviews", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.datetime "created_at", null: false
    t.bigint "review_id", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id", "review_id"], name: "index_article_reviews_on_article_id_and_review_id", unique: true
    t.index ["article_id"], name: "index_article_reviews_on_article_id"
    t.index ["review_id"], name: "index_article_reviews_on_review_id"
  end

  create_table "article_tags", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.datetime "created_at", null: false
    t.bigint "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id", "tag_id"], name: "index_article_tags_on_article_id_and_tag_id", unique: true
    t.index ["article_id"], name: "index_article_tags_on_article_id"
    t.index ["tag_id"], name: "index_article_tags_on_tag_id"
  end

  create_table "article_vintages", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vintage_id", null: false
    t.index ["article_id", "vintage_id"], name: "index_article_vintages_on_article_id_and_vintage_id", unique: true
    t.index ["article_id"], name: "index_article_vintages_on_article_id"
    t.index ["vintage_id"], name: "index_article_vintages_on_vintage_id"
  end

  create_table "articles", force: :cascade do |t|
    t.text "abstract"
    t.text "body"
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.datetime "published_at"
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["category_id"], name: "index_articles_on_category_id"
    t.index ["slug"], name: "index_articles_on_slug", unique: true
    t.index ["user_id"], name: "index_articles_on_user_id"
  end

  create_table "billing_customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "provider", null: false
    t.string "provider_customer_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["provider", "provider_customer_id"], name: "index_billing_customers_on_provider_and_provider_customer_id", unique: true
    t.index ["user_id", "provider"], name: "index_billing_customers_on_user_id_and_provider", unique: true
    t.index ["user_id"], name: "index_billing_customers_on_user_id"
  end

  create_table "billing_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type"
    t.jsonb "payload", default: {}
    t.datetime "processed_at"
    t.string "provider", null: false
    t.string "provider_event_id", null: false
    t.datetime "updated_at", null: false
    t.index ["processed_at"], name: "index_billing_events_on_processed_at", where: "(processed_at IS NULL)"
    t.index ["provider", "provider_event_id"], name: "index_billing_events_on_provider_and_provider_event_id", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "for_article", default: false, null: false
    t.boolean "for_review", default: false, null: false
    t.boolean "for_wine", default: false, null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "sort_order_article"
    t.integer "sort_order_review"
    t.integer "sort_order_wine"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "countries", force: :cascade do |t|
    t.string "code"
    t.string "continent"
    t.datetime "created_at", null: false
    t.string "flag_emoji"
    t.boolean "is_wine_country", default: false, null: false
    t.string "name"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_countries_on_code", unique: true
    t.index ["name"], name: "index_countries_on_name", unique: true
    t.index ["slug"], name: "index_countries_on_slug", unique: true
  end

  create_table "grapes", force: :cascade do |t|
    t.string "color"
    t.bigint "country_id"
    t.datetime "created_at", null: false
    t.boolean "is_blending_grape", default: false, null: false
    t.text "main_regions", default: [], array: true
    t.string "name", null: false
    t.text "notes", default: [], array: true
    t.string "origin_country"
    t.integer "relevance"
    t.text "serving"
    t.string "slug", null: false
    t.text "synonyms", default: [], array: true
    t.datetime "updated_at", null: false
    t.index ["country_id"], name: "index_grapes_on_country_id"
    t.index ["name"], name: "index_grapes_on_name", unique: true
    t.index ["slug"], name: "index_grapes_on_slug", unique: true
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti"
  end

  create_table "producer_grapes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "grape_id", null: false
    t.bigint "producer_id", null: false
    t.datetime "updated_at", null: false
    t.index ["grape_id"], name: "index_producer_grapes_on_grape_id"
    t.index ["producer_id", "grape_id"], name: "index_producer_grapes_on_producer_id_and_grape_id", unique: true
    t.index ["producer_id"], name: "index_producer_grapes_on_producer_id"
  end

  create_table "producer_regions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "producer_id", null: false
    t.bigint "region_id", null: false
    t.datetime "updated_at", null: false
    t.index ["producer_id", "region_id"], name: "index_producer_regions_on_producer_id_and_region_id", unique: true
    t.index ["producer_id"], name: "index_producer_regions_on_producer_id"
    t.index ["region_id"], name: "index_producer_regions_on_region_id"
  end

  create_table "producers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "country_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "email"
    t.string "facebook"
    t.integer "founded_year"
    t.string "instagram"
    t.string "legal_name"
    t.string "name"
    t.string "phone"
    t.integer "producer_type", default: 0, null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["name"], name: "index_producers_on_name", unique: true
    t.index ["slug"], name: "index_producers_on_slug", unique: true
  end

  create_table "regions", force: :cascade do |t|
    t.bigint "country_id", null: false
    t.datetime "created_at", null: false
    t.boolean "is_appellation", default: false, null: false
    t.boolean "is_state", default: false, null: false
    t.string "name", null: false
    t.bigint "parent_id"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id"], name: "index_regions_on_country_id"
    t.index ["name", "parent_id"], name: "index_regions_on_name_and_parent_id"
    t.index ["parent_id"], name: "index_regions_on_parent_id"
    t.index ["slug"], name: "index_regions_on_slug", unique: true
  end

  create_table "review_categories", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.bigint "review_id", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_review_categories_on_category_id"
    t.index ["review_id", "category_id"], name: "index_review_categories_on_review_id_and_category_id", unique: true
    t.index ["review_id"], name: "index_review_categories_on_review_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "category_id"
    t.text "comment"
    t.datetime "created_at", null: false
    t.integer "drink_from"
    t.boolean "drink_plus", default: false, null: false
    t.integer "drink_to"
    t.datetime "published_at"
    t.decimal "score", precision: 5, scale: 2
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "vintage_id", null: false
    t.index ["category_id"], name: "index_reviews_on_category_id"
    t.index ["slug"], name: "index_reviews_on_slug", unique: true
    t.index ["user_id"], name: "index_reviews_on_user_id"
    t.index ["vintage_id"], name: "index_reviews_on_vintage_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.integer "completed_jobs", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "enqueued_at"
    t.datetime "failed_at"
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "finished_at"
    t.text "metadata"
    t.text "on_failure"
    t.text "on_finish"
    t.text "on_success"
    t.integer "total_jobs", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.bigint "batch_id"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "subscription_billing_prices", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "amount_cents"
    t.string "billing_interval", default: "year", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "AUD", null: false
    t.string "provider", null: false
    t.string "provider_price_id"
    t.string "provider_product_id"
    t.bigint "subscription_id", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "provider_price_id"], name: "idx_on_provider_provider_price_id_b753013e4c", unique: true
    t.index ["subscription_id", "provider"], name: "idx_on_subscription_id_provider_4ac4f5f044", unique: true
    t.index ["subscription_id"], name: "index_subscription_billing_prices_on_subscription_id"
  end

  create_table "subscription_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_subscription_features_on_slug", unique: true
  end

  create_table "subscription_subscription_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.bigint "subscription_feature_id", null: false
    t.bigint "subscription_id", null: false
    t.datetime "updated_at", null: false
    t.index ["subscription_feature_id"], name: "idx_on_subscription_feature_id_3c98fc1405"
    t.index ["subscription_id", "subscription_feature_id"], name: "index_sub_sub_features_on_sub_and_feature", unique: true
    t.index ["subscription_id"], name: "index_subscription_subscription_features_on_subscription_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "AUD", null: false
    t.text "description"
    t.boolean "is_default", default: false, null: false
    t.integer "monthly_price_cents"
    t.string "name", null: false
    t.boolean "popular", default: false, null: false
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.boolean "visible", default: true, null: false
    t.integer "yearly_price_cents"
    t.index ["is_default"], name: "index_subscriptions_on_is_default", unique: true, where: "(is_default = true)"
    t.index ["name"], name: "index_subscriptions_on_name", unique: true
    t.index ["slug"], name: "index_subscriptions_on_slug", unique: true
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["slug"], name: "index_tags_on_slug", unique: true
  end

  create_table "taste_parameters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "help"
    t.string "high"
    t.string "label"
    t.string "low"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_taste_parameters_on_slug", unique: true
  end

  create_table "user_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "user_subscriptions", force: :cascade do |t|
    t.string "billing_provider", default: "manual", null: false
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.string "provider_subscription_id"
    t.datetime "started_at", null: false
    t.string "status", default: "active", null: false
    t.bigint "subscription_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["subscription_id"], name: "index_user_subscriptions_on_subscription_id"
    t.index ["user_id", "status"], name: "index_user_subscriptions_on_user_id_and_status"
    t.index ["user_id"], name: "index_user_subscriptions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", default: ""
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.bigint "subscription_id"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["subscription_id"], name: "index_users_on_subscription_id"
  end

  create_table "vintages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "no_vintage", default: false, null: false
    t.integer "price_cents"
    t.text "prompt"
    t.datetime "updated_at", null: false
    t.bigint "wine_id"
    t.integer "year", null: false
    t.index ["wine_id"], name: "index_vintages_on_wine_id"
  end

  create_table "wine_categories", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "wine_id", null: false
    t.index ["category_id"], name: "index_wine_categories_on_category_id"
    t.index ["wine_id", "category_id"], name: "index_wine_categories_on_wine_id_and_category_id", unique: true
    t.index ["wine_id"], name: "index_wine_categories_on_wine_id"
  end

  create_table "wine_grapes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "grape_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "wine_id", null: false
    t.index ["grape_id"], name: "index_wine_grapes_on_grape_id"
    t.index ["wine_id", "grape_id"], name: "index_wine_grapes_on_wine_id_and_grape_id", unique: true
    t.index ["wine_id"], name: "index_wine_grapes_on_wine_id"
  end

  create_table "wine_profile_taste_parameters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "score"
    t.bigint "taste_parameter_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "wine_profile_id", null: false
    t.index ["taste_parameter_id", "wine_profile_id"], name: "idx_on_taste_parameter_id_wine_profile_id_d29b288454", unique: true
    t.index ["taste_parameter_id"], name: "index_wine_profile_taste_parameters_on_taste_parameter_id"
    t.index ["wine_profile_id", "taste_parameter_id"], name: "idx_on_wine_profile_id_taste_parameter_id_b0069b6cac", unique: true
    t.index ["wine_profile_id"], name: "index_wine_profile_taste_parameters_on_wine_profile_id"
  end

  create_table "wine_profiles", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.text "grapes"
    t.string "name"
    t.text "notes"
    t.text "parameters"
    t.text "regions"
    t.text "serving"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["grapes"], name: "index_wine_profiles_on_grapes_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["name"], name: "index_wine_profiles_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["regions"], name: "index_wine_profiles_on_regions_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["slug"], name: "index_wine_profiles_on_slug", unique: true
  end

  create_table "wine_regions", force: :cascade do |t|
    t.bigint "region_id", null: false
    t.bigint "wine_id", null: false
    t.index ["region_id"], name: "index_wine_regions_on_region_id"
    t.index ["wine_id", "region_id"], name: "index_wine_regions_on_wine_id_and_region_id", unique: true
  end

  create_table "wine_taste_parameters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "score"
    t.bigint "taste_parameter_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "wine_id", null: false
    t.index ["taste_parameter_id", "wine_id"], name: "index_wine_taste_parameters_on_taste_parameter_id_and_wine_id", unique: true
    t.index ["taste_parameter_id"], name: "index_wine_taste_parameters_on_taste_parameter_id"
    t.index ["wine_id", "taste_parameter_id"], name: "index_wine_taste_parameters_on_wine_id_and_taste_parameter_id", unique: true
    t.index ["wine_id"], name: "index_wine_taste_parameters_on_wine_id"
  end

  create_table "wines", force: :cascade do |t|
    t.decimal "alcohol_percentage", precision: 10, scale: 2
    t.bigint "category_id"
    t.string "closure"
    t.string "color"
    t.datetime "created_at", null: false
    t.string "designation_name"
    t.boolean "fortified", default: false, null: false
    t.string "name"
    t.bigint "producer_id", null: false
    t.text "prompt"
    t.string "slug"
    t.boolean "sparkling", default: false, null: false
    t.datetime "updated_at", null: false
    t.integer "volume_ml"
    t.index ["category_id"], name: "index_wines_on_category_id"
    t.index ["name"], name: "index_wines_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["producer_id"], name: "index_wines_on_producer_id"
    t.index ["slug"], name: "index_wines_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "addresses", "countries"
  add_foreign_key "addresses", "producers"
  add_foreign_key "article_categories", "articles"
  add_foreign_key "article_categories", "categories"
  add_foreign_key "article_producers", "articles"
  add_foreign_key "article_producers", "producers"
  add_foreign_key "article_reviews", "articles"
  add_foreign_key "article_reviews", "reviews"
  add_foreign_key "article_tags", "articles"
  add_foreign_key "article_tags", "tags"
  add_foreign_key "article_vintages", "articles"
  add_foreign_key "article_vintages", "vintages"
  add_foreign_key "articles", "categories"
  add_foreign_key "articles", "users"
  add_foreign_key "billing_customers", "users"
  add_foreign_key "grapes", "countries"
  add_foreign_key "producer_grapes", "grapes"
  add_foreign_key "producer_grapes", "producers"
  add_foreign_key "producer_regions", "producers"
  add_foreign_key "producer_regions", "regions"
  add_foreign_key "regions", "countries"
  add_foreign_key "regions", "regions", column: "parent_id"
  add_foreign_key "review_categories", "categories"
  add_foreign_key "review_categories", "reviews"
  add_foreign_key "reviews", "categories"
  add_foreign_key "reviews", "users"
  add_foreign_key "reviews", "vintages"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "subscription_billing_prices", "subscriptions"
  add_foreign_key "subscription_subscription_features", "subscription_features"
  add_foreign_key "subscription_subscription_features", "subscriptions"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "user_subscriptions", "subscriptions"
  add_foreign_key "user_subscriptions", "users"
  add_foreign_key "users", "subscriptions"
  add_foreign_key "vintages", "wines"
  add_foreign_key "wine_categories", "categories"
  add_foreign_key "wine_categories", "wines"
  add_foreign_key "wine_grapes", "grapes"
  add_foreign_key "wine_grapes", "wines"
  add_foreign_key "wine_profile_taste_parameters", "taste_parameters"
  add_foreign_key "wine_profile_taste_parameters", "wine_profiles"
  add_foreign_key "wine_regions", "regions"
  add_foreign_key "wine_regions", "wines"
  add_foreign_key "wine_taste_parameters", "taste_parameters"
  add_foreign_key "wine_taste_parameters", "wines"
  add_foreign_key "wines", "categories"
  add_foreign_key "wines", "producers"
end
