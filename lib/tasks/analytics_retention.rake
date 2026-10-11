# frozen_string_literal: true

# Retention cleanup rake task (Phase 11).
#
# Usage:
#   rake analytics:retention:cleanup                    # Run cleanup (dry-run by default)
#   rake analytics:retention:cleanup[false]             # Actually delete
#   rake analytics:retention:cleanup[false,2000,730,20] # Custom: dry_run, batch_size, retention_days, max_batches
#   rake analytics:retention:status                     # Show status without deleting
#   rake analytics:retention:guidance                   # Show scheduler guidance
#
namespace :analytics do
  namespace :retention do
    desc "Clean up old analytics events (dry-run by default)"
    task :cleanup, [:dry_run, :batch_size, :retention_days, :max_batches] => :environment do |t, args|
      dry_run = args[:dry_run] != "false" # default true for safety
      batch_size = args[:batch_size]&.to_i
      retention_days = args[:retention_days]&.to_i
      max_batches = args[:max_batches]&.to_i

      puts "=== Analytics Retention Cleanup ==="
      puts "Dry run: #{dry_run}"
      puts "Batch size: #{batch_size || Analytics::Retention::DEFAULT_BATCH_SIZE}"
      puts "Retention days: #{retention_days || Analytics::Retention::DEFAULT_RETENTION_DAYS}"
      puts "Max batches: #{max_batches || 10}"
      puts ""

      result = Analytics::Retention.cleanup(
        dry_run: dry_run,
        batch_size: batch_size,
        retention_days: retention_days,
        max_batches: max_batches
      )

      puts "Result:"
      puts "  Deleted (or would delete): #{result[:deleted]}"
      puts "  Scanned: #{result[:scanned]}"
      puts "  Batches processed: #{result[:batches]}"
      puts "  Cutoff date: #{result[:cutoff_date]}"
      puts "  Retention days: #{result[:retention_days]}"
      puts ""
      puts dry_run ? "DRY RUN - no data was deleted. Run with 'false' to actually delete." : "CLEANUP COMPLETE"
    end

    desc "Show retention status without modifying data"
    task :status, [:retention_days] => :environment do |t, args|
      retention_days = args[:retention_days]&.to_i

      puts "=== Analytics Retention Status ==="
      puts ""

      result = Analytics::Retention.status(retention_days: retention_days)

      puts "Events before cutoff: #{result[:events_before_cutoff]}"
      puts "Cutoff date: #{result[:cutoff_date]}"
      puts "Oldest event: #{result[:oldest_event] || 'none'}"
      puts "Newest event: #{result[:newest_event] || 'none'}"
      puts "Retention days: #{result[:retention_days]}"
    end

    desc "Show scheduler guidance for retention cleanup"
    task :guidance => :environment do
      puts "=== Analytics Retention Scheduler Guidance ==="
      puts ""

      result = Analytics::Retention.scheduler_guidance

      puts "Recommended cron schedule: #{result[:recommended_schedule]}"
      puts "Batch size: #{result[:batch_size]}"
      puts "Retention days: #{result[:retention_days]}"
      puts "Estimated batches per run: #{result[:estimated_batches_per_run]}"
      puts ""
      puts "Monitoring:"
      result[:monitoring].each do |key, value|
        puts "  #{key}: #{value}"
      end
      puts ""
      puts "Add to sidekiq-scheduler (config/schedule.yml) or system cron:"
      puts "  # Daily at 03:00 UTC"
      puts "  0 3 * * * cd /app && bundle exec rake analytics:retention:cleanup[false]"
    end
  end
end