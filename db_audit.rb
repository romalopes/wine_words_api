#!/usr/bin/env ruby
# frozen_string_literal: true

# Database Audit Script for Wine Words API
# Run with: bundle exec ruby db_audit.rb

require_relative "config/environment"

module DbAudit
  class << self
    def run
      puts "=" * 80
      puts "DATABASE AUDIT REPORT - #{Time.current}"
      puts "=" * 80

      audit_schema
      audit_data_types
      audit_missing_foreign_keys
      audit_code_validations_vs_db_constraints
      audit_transaction_coverage
      audit_indexes
      audit_security
      audit_temporal_needs

      puts "\n" + "=" * 80
      puts "AUDIT COMPLETE"
      puts "=" * 80
    end

    private

    def audit_schema
      puts "\n## 1. SCHEMA OVERVIEW"
      puts "-" * 40

      tables = ActiveRecord::Base.connection.tables.sort
      puts "Total tables: #{tables.count}"

      tables.each do |table|
        next if table.start_with?("solid_", "active_storage_", "ar_internal_metadata", "schema_migrations")

        columns = ActiveRecord::Base.connection.columns(table)
        indexes = ActiveRecord::Base.connection.indexes(table)
        fks = ActiveRecord::Base.connection.foreign_keys(table)

        puts "\n### #{table}"
        puts "  Columns: #{columns.count}"
        columns.each do |col|
          null_str = col.null ? "NULL" : "NOT NULL"
          default_str = col.default ? " DEFAULT #{col.default}" : ""
          puts "    - #{col.name}: #{col.sql_type} #{null_str}#{default_str}"
        end
        puts "  Indexes: #{indexes.count}"
        indexes.each { |idx| cols = idx.columns.is_a?(Array) ? idx.columns.join(', ') : idx.columns; puts "    - #{idx.name}: #{cols}#{idx.unique ? ' (UNIQUE)' : ''}" }
        puts "  Foreign Keys: #{fks.count}"
        fks.each { |fk| puts "    - #{fk.column} -> #{fk.to_table}.#{fk.primary_key} (on_delete: #{fk.on_delete})" }
      end
    end

    def audit_data_types
      puts "\n## 2. DATA TYPE ISSUES"
      puts "-" * 40

      issues = []

      # Money in float/real/double
      ActiveRecord::Base.connection.tables.each do |table|
        next if table.start_with?("solid_", "active_storage_", "ar_internal_metadata", "schema_migrations")
        columns = ActiveRecord::Base.connection.columns(table)
        columns.each do |col|
          if col.sql_type =~ /float|real|double/i && col.name =~ /price|amount|cost|fee|total|subtotal|tax|shipping|discount|balance|credit|debit|payment|invoice|quote|trade_price|retail_price/i
            issues << "MONEY_IN_FLOAT: #{table}.#{col.name} (#{col.sql_type})"
          end
          if col.sql_type =~ /timestamp without time zone/i
            issues << "TIMESTAMP_NO_TZ: #{table}.#{col.name} (#{col.sql_type})"
          end
          if col.sql_type =~ /text|varchar|string/i && col.name =~ /_at$|_date$|_on$|_timestamp$|_year$|_month$|_day$/i
            issues << "TEXT_STORING_DATE: #{table}.#{col.name} (#{col.sql_type})"
          end
          if col.sql_type =~ /text|varchar|string/i && col.name =~ /^.*_id$/ && col.name != "id"
            issues << "TEXT_STORING_ID: #{table}.#{col.name} (#{col.sql_type})"
          end
        end
      end

      # Find duplicated data across tables
      find_duplicated_columns

      if issues.empty?
        puts "  No data type issues found"
      else
        issues.each { |issue| puts "  ⚠ #{issue}" }
      end
    end

    def find_duplicated_columns
      # Check for columns with same name and type across multiple tables that could be normalized
      column_map = Hash.new { |h, k| h[k] = [] }

      ActiveRecord::Base.connection.tables.each do |table|
        next if table.start_with?("solid_", "active_storage_", "ar_internal_metadata", "schema_migrations")
        columns = ActiveRecord::Base.connection.columns(table)
        columns.each do |col|
          key = "#{col.name}:#{col.sql_type}"
          column_map[key] << table
        end
      end

      column_map.each do |key, tables|
        next if tables.size < 3 # Only flag if in 3+ tables
        next if key.start_with?("id:", "created_at:", "updated_at:", "uuid:")
        puts "  📋 DUPLICATED_COLUMN: #{key} in #{tables.join(', ')}"
      end
    end

    def audit_missing_foreign_keys
      puts "\n## 3. MISSING FOREIGN KEYS"
      puts "-" * 40

      # Get all columns ending in _id that reference other tables
      all_tables = ActiveRecord::Base.connection.tables - ["schema_migrations", "ar_internal_metadata"]
      all_tables.reject! { |t| t.start_with?("solid_", "active_storage_") }

      missing_fks = []

      all_tables.each do |table|
        columns = ActiveRecord::Base.connection.columns(table)
        fks = ActiveRecord::Base.connection.foreign_keys(table)
        fk_columns = fks.map(&:column)

        columns.each do |col|
          next unless col.name.end_with?("_id")
          next if fk_columns.include?(col.name)
          next if col.name == "id"

          # Check if referenced table exists
          ref_table = col.name.sub(/_id$/, "").pluralize
          if all_tables.include?(ref_table)
            missing_fks << "#{table}.#{col.name} -> #{ref_table}"
          end
        end
      end

      if missing_fks.empty?
        puts "  No missing foreign keys detected"
      else
        missing_fks.each { |fk| puts "  ⚠ #{fk}" }
      end
    end

    def audit_code_validations_vs_db_constraints
      puts "\n## 4. CODE VALIDATIONS vs DB CONSTRAINTS"
      puts "-" * 40

      models = ActiveRecord::Base.descendants.select { |m| m.table_exists? }

      models.each do |model|
        next if model.name.start_with?("ActiveStorage", "Solid", "ActionText", "ActionMailbox")

        validations = model.validators.map do |v|
          attrs = v.attributes.join(", ")
          type = v.class.name.demodulize.gsub("Validator", "")
          options = v.options.except(:_union).inspect
          "#{type}(#{attrs}) #{options}"
        end

        next if validations.empty?

        puts "\n### #{model.name} (#{model.table_name})"
        validations.each { |v| puts "  - #{v}" }

        check_db_constraints(model)
      end
    end

    def check_db_constraints(model)
      table = model.table_name
      columns = ActiveRecord::Base.connection.columns(table)
      indexes = ActiveRecord::Base.connection.indexes(table)
      fks = ActiveRecord::Base.connection.foreign_keys(table)
      check_constraints = ActiveRecord::Base.connection.check_constraints(table) rescue []

      model.validators.each do |validator|
        case validator
        when ActiveRecord::Validations::PresenceValidator
          validator.attributes.each do |attr|
            col = columns.find { |c| c.name == attr.to_s }
            if col && col.null
              puts "    MISSING NOT NULL: #{table}.#{attr} (validated in code, nullable in DB)"
            end
          end
        when ActiveRecord::Validations::UniquenessValidator
          validator.attributes.each do |attr|
            idx = indexes.find { |i| i.columns == [attr.to_s] && i.unique }
            unless idx
              puts "    MISSING UNIQUE INDEX: #{table}.#{attr} (validated in code, no unique index)"
            end
          end
        when ActiveRecord::Validations::NumericalityValidator
          validator.attributes.each do |attr|
            col = columns.find { |c| c.name == attr.to_s }
            if col && validator.options[:greater_than_or_equal_to] == 0
              chk = check_constraints.find { |c| c.expression.include?(attr.to_s) && c.expression.include?(">=") }
              unless chk
                puts "    MISSING CHECK (>= 0): #{table}.#{attr}"
              end
            end
          end
        when ActiveModel::Validations::InclusionValidator
          validator.attributes.each do |attr|
            values = validator.options[:in] || validator.options[:within]
            if values
              chk = check_constraints.find { |c| c.expression.include?(attr.to_s) && c.expression.include?("IN") }
              unless chk
                puts "    MISSING CHECK (IN enum): #{table}.#{attr} IN (#{values.join(', ')})"
              end
            end
          end
        end
      end

      model.reflect_on_all_associations(:belongs_to).each do |assoc|
        next if assoc.options[:polymorphic]
        fk_col = assoc.foreign_key
        fk = fks.find { |f| f.column == fk_col }
        unless fk
          puts "    MISSING FK: #{table}.#{fk_col} -> #{assoc.klass.table_name} (belongs_to :#{assoc.name})"
        end
      end
    end

    def audit_transaction_coverage
      puts "\n## 5. TRANSACTION COVERAGE ANALYSIS"
      puts "-" * 40

      scan_for_transactions("app/controllers")
      scan_for_transactions("app/services")
    end

    def scan_for_transactions(path)
      Dir.glob("#{path}/**/*.rb").each do |file|
        content = File.read(file)
        next unless content =~ /\.create!|\.save!|\.update!|\.destroy!/

        in_transaction = content =~ /ActiveRecord::Base\.transaction|transaction do/

        mutations = content.scan(/\.(create|save|update|destroy)!?\(/).size

        if mutations > 1 && !in_transaction
          puts "  POTENTIAL TRANSACTION GAP: #{file} (#{mutations} mutations, no transaction block)"
        end
      end
    end

    def audit_indexes
      puts "\n## 6. INDEX ANALYSIS"
      puts "-" * 40

      issues = []

      ActiveRecord::Base.connection.tables.each do |table|
        next if table.start_with?("solid_", "active_storage_", "ar_internal_metadata", "schema_migrations")

        columns = ActiveRecord::Base.connection.columns(table)
        indexes = ActiveRecord::Base.connection.indexes(table)
        fks = ActiveRecord::Base.connection.foreign_keys(table)

        fks.each do |fk|
          idx = indexes.find { |i| i.columns.first == fk.column }
          unless idx
            issues << "MISSING FK INDEX: #{table}.#{fk.column} (FK to #{fk.to_table})"
          end
        end
      end

      if issues.empty?
        puts "  No obvious missing indexes found"
      else
        issues.each { |issue| puts "  #{issue}" }
      end
    end

    def audit_security
      puts "\n## 7. SECURITY AUDIT"
      puts "-" * 40

      pii_columns = []
      ActiveRecord::Base.connection.tables.each do |table|
        next if table.start_with?("solid_", "active_storage_", "ar_internal_metadata", "schema_migrations")
        columns = ActiveRecord::Base.connection.columns(table)
        columns.each do |col|
          if col.name =~ /email|phone|address|ssn|tax|birth|name|first_name|last_name|password|token|secret|key/i
            pii_columns << "#{table}.#{col.name} (#{col.sql_type})"
          end
        end
      end

      puts "  PII Columns found: #{pii_columns.count}"
      pii_columns.first(20).each { |c| puts "    - #{c}" }
      puts "    ..." if pii_columns.count > 20

      puts "\n  Checking for secrets in schema..."
    end

    def audit_temporal_needs
      puts "\n## 8. TEMPORAL TABLES / AUDIT HISTORY NEEDS"
      puts "-" * 40

      critical_tables = %w[
        wine_packages wine_package_items wine_package_events
        users subscriptions user_subscriptions subscription_changes
        subscription_billing_prices
        reviews wines vintages producers
        trade_idempotency_keys
      ]

      puts "  Critical tables needing audit history:"
      critical_tables.each do |table|
        exists = ActiveRecord::Base.connection.table_exists?(table)
        history_exists = ActiveRecord::Base.connection.table_exists?("#{table}_history")
        status = exists ? (history_exists ? "HISTORY EXISTS" : "NEEDS HISTORY") : "TABLE MISSING"
        puts "    - #{table}: #{status}"
      end
    end
  end
end

DbAudit.run