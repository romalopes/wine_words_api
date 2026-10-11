# Retention cleanup for analytics events (Phase 11).
#
# Idempotent, bounded, configurable cleanup with dry-run support.
# Removes accepted events older than the retention cutoff in small
# repeatable batches. Missing scheduler execution is made observable.
module Analytics
  class Retention
    DEFAULT_BATCH_SIZE = 1000
    DEFAULT_RETENTION_DAYS = 730 # 2 years
    MAX_BATCH_SIZE = 5000

    # Cleanup events older than retention cutoff.
    #
    # @param options [Hash]
    #   - dry_run: true to only count without deleting (default: false)
    #   - batch_size: rows per transaction (default: 1000, max: 5000)
    #   - retention_days: days to retain (default: 730)
    #   - max_batches: safety limit on batches per run (default: 10)
    # @return [Hash] { deleted: count, scanned: count, dry_run: bool, batches: count, cutoff_date: date }
    def self.cleanup(options = {})
      dry_run = options[:dry_run] == true
      batch_size = [[options[:batch_size]&.to_i || DEFAULT_BATCH_SIZE, 1].max, MAX_BATCH_SIZE].min
      retention_days = [options[:retention_days]&.to_i || DEFAULT_RETENTION_DAYS, 1].max
      max_batches = [options[:max_batches]&.to_i || 10, 1].max

      cutoff_date = retention_days.days.ago.to_date
      total_deleted = 0
      total_scanned = 0
      batches = 0

      loop do
        break if batches >= max_batches

        # Use a subquery to avoid loading all IDs into memory
        batch_scope = Event.accepted
                           .where("viewed_at < ?", cutoff_date)
                           .order(:id)
                           .limit(batch_size)

        ids = batch_scope.pluck(:id)
        break if ids.empty?

        total_scanned += ids.size
        batches += 1

        if dry_run
          total_deleted += ids.size # would be deleted
        else
          # Use delete_all for efficiency (no callbacks needed)
          deleted = Event.where(id: ids).delete_all
          total_deleted += deleted
        end

        # Safety: if we got fewer IDs than batch_size, we're done
        break if ids.size < batch_size
      end

      {
        deleted: total_deleted,
        scanned: total_scanned,
        dry_run: dry_run,
        batches: batches,
        cutoff_date: cutoff_date.iso8601,
        retention_days: retention_days
      }
    end

    # Get retention status without modifying data.
    #
    # @return [Hash] { events_before_cutoff: count, cutoff_date: date, oldest_event: date, newest_event: date }
    def self.status(options = {})
      retention_days = [options[:retention_days]&.to_i || DEFAULT_RETENTION_DAYS, 1].max
      cutoff_date = retention_days.days.ago.to_date

      scope = Event.accepted
      events_before_cutoff = scope.where("viewed_at < ?", cutoff_date).count
      oldest = scope.minimum(:viewed_at)
      newest = scope.maximum(:viewed_at)

      {
        events_before_cutoff: events_before_cutoff,
        cutoff_date: cutoff_date.iso8601,
        oldest_event: oldest&.to_date&.iso8601,
        newest_event: newest&.to_date&.iso8601,
        retention_days: retention_days
      }
    end

    # Scheduler guidance: returns recommended cron schedule based on config.
    # Call this from a rake task or initializer to validate scheduling.
    def self.scheduler_guidance
      batch_size = Rails.application.config.analytics[:batch_size] || DEFAULT_BATCH_SIZE
      retention_days = ENV.fetch("ANALYTICS_RETENTION_DAYS", DEFAULT_RETENTION_DAYS).to_i

      {
        recommended_schedule: "0 3 * * *", # Daily at 03:00 UTC
        batch_size: batch_size,
        retention_days: retention_days,
        estimated_batches_per_run: estimate_batches_per_run(batch_size, retention_days),
        monitoring: {
          metric: "analytics.retention.deleted",
          alert_if_zero_batches_for: "3 days",
          alert_if_errors: true
        }
      }
    end

    private

    def self.estimate_batches_per_run(batch_size, retention_days)
      # Rough estimate: assume uniform distribution over retention period
      total_events = Event.accepted.count
      return 0 if total_events.zero?

      days_with_data = [(Date.current - (Event.accepted.minimum(:viewed_at)&.to_date || Date.current)).to_i, 1].max
      events_per_day = total_events.to_f / days_with_data
      events_to_clean = events_per_day * [retention_days, days_with_data].min
      (events_to_clean / batch_size).ceil
    end
  end
end