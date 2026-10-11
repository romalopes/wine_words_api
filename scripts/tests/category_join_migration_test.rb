# Run against a disposable PostgreSQL database only:
# CATEGORY_MIGRATION_TEST_URL=postgresql:///disposable bundle exec ruby scripts/tests/category_join_migration_test.rb
require "active_record"
require "securerandom"
require_relative "../../db/migrate/20260827000000_create_category_join_tables"

ActiveRecord::Base.establish_connection(ENV.fetch("CATEGORY_MIGRATION_TEST_URL"))
connection = ActiveRecord::Base.connection
schema = "category_migration_test_#{SecureRandom.hex(8)}"
connection.execute("CREATE SCHEMA #{schema}")
connection.schema_search_path = schema
ActiveRecord::Migration.verbose = false

begin
  %i[wines reviews articles categories].each { |table| connection.create_table(table) }
  migration = CreateCategoryJoinTables.new
  # Simulate an existing table with data but no indexes or foreign keys.
  connection.create_table(:wine_categories) do |t|
    t.bigint :wine_id, null: false
    t.bigint :category_id, null: false
    t.timestamps
  end
  connection.execute("INSERT INTO wines (id) VALUES (1)")
  connection.execute("INSERT INTO categories (id) VALUES (1)")
  connection.execute("INSERT INTO wine_categories (wine_id, category_id, created_at, updated_at) VALUES (1, 1, NOW(), NOW())")
  2.times { connection.transaction { migration.migrate(:up) } }
  raise "Existing data lost" unless connection.select_value("SELECT count(*) FROM wine_categories").to_i == 1
  { wine_categories: :wine, review_categories: :review, article_categories: :article }.each do |table, owner|
    raise "Missing unique index" unless connection.index_exists?(table, ["#{owner}_id", "category_id"], unique: true)
    [owner, :category].each do |reference|
      raise "Missing reference index" unless connection.index_exists?(table, "#{reference}_id")
      raise "Missing foreign key" unless connection.foreign_key_exists?(table, reference.to_s.pluralize, column: "#{reference}_id")
    end
  end
  begin
    migration.migrate(:down)
    raise "Unsafe rollback allowed"
  rescue ActiveRecord::IrreversibleMigration
    # Expected: adopted tables must not be dropped.
  end
  puts "Category migration passed: existing rows preserved, missing tables and constraints created, rerun safe, rollback blocked."
ensure
  connection.schema_search_path = "public"
  connection.execute("DROP SCHEMA #{schema} CASCADE")
end
