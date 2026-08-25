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

ActiveRecord::Schema[8.1].define(version: 2026_08_26_012903) do
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

  create_table "article_wines", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "wine_id", null: false
    t.index ["article_id", "wine_id"], name: "index_article_wines_on_article_id_and_wine_id", unique: true
    t.index ["article_id"], name: "index_article_wines_on_article_id"
    t.index ["wine_id"], name: "index_article_wines_on_wine_id"
  end

  create_table "articles", force: :cascade do |t|
    t.text "abstract"
    t.text "body"
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.datetime "published_at"
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["category_id"], name: "index_articles_on_category_id"
    t.index ["user_id"], name: "index_articles_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti"
  end

  create_table "producers", force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_producers_on_name", unique: true
    t.index ["slug"], name: "index_producers_on_slug", unique: true
  end

  create_table "reviews", force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "published_at"
    t.decimal "score", precision: 5, scale: 2
    t.string "status", default: "draft", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "vintage_id", null: false
    t.index ["user_id"], name: "index_reviews_on_user_id"
    t.index ["vintage_id"], name: "index_reviews_on_vintage_id"
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

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", default: ""
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "vintages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "prompt"
    t.datetime "updated_at", null: false
    t.bigint "wine_id"
    t.integer "year", null: false
    t.index ["wine_id"], name: "index_vintages_on_wine_id"
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
    t.string "closure"
    t.string "color"
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "producer_id"
    t.text "prompt"
    t.string "region"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.integer "volume_ml"
    t.index ["name"], name: "index_wines_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["producer_id"], name: "index_wines_on_producer_id"
    t.index ["region"], name: "index_wines_on_region_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["slug"], name: "index_wines_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "article_producers", "articles"
  add_foreign_key "article_producers", "producers"
  add_foreign_key "article_reviews", "articles"
  add_foreign_key "article_reviews", "reviews"
  add_foreign_key "article_tags", "articles"
  add_foreign_key "article_tags", "tags"
  add_foreign_key "article_wines", "articles"
  add_foreign_key "article_wines", "wines"
  add_foreign_key "articles", "categories"
  add_foreign_key "articles", "users"
  add_foreign_key "reviews", "users"
  add_foreign_key "reviews", "vintages"
  add_foreign_key "vintages", "wines"
  add_foreign_key "wine_profile_taste_parameters", "taste_parameters"
  add_foreign_key "wine_profile_taste_parameters", "wine_profiles"
  add_foreign_key "wine_taste_parameters", "taste_parameters"
  add_foreign_key "wine_taste_parameters", "wines"
  add_foreign_key "wines", "producers"
end
