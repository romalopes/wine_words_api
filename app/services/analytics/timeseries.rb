# Phase 7: Timeseries aggregation service.
#
# Aggregate time-series buckets across all authorized content within the
# validated period. Used for dashboard charts (views over time).
#
# Returns { buckets: [...], total_views: Integer, period: {...} }
module Analytics
  class Timeseries
    GROUPINGS = %w[day week month].freeze

    def self.call(scope, period, params)
      new(scope, period, params).call
    end

    def initialize(scope, period, params)
      @scope = scope
      @period = period
      @params = params
    end

    def call
      return empty_result if @period.empty?

      grouping = GROUPINGS.include?(@params[:grouping].to_s) ? @params[:grouping].to_s : "day"

      # Build bucket edges
      bucket_seconds = case grouping
      when "day" then 1.day
      when "week" then 1.week
      when "month" then 1.month
      end

      edges = []
      cursor = @period.start_at
      while cursor < @period.end_at
        if grouping == "month"
          # Month boundaries need calendar awareness
          bucket_end = (cursor + 1.month).beginning_of_month
          bucket_end = @period.end_at if bucket_end > @period.end_at
        else
          bucket_end = [cursor + bucket_seconds, @period.end_at].min
        end
        edges << [cursor, bucket_end]
        cursor = bucket_end
      end

      # Load all accepted events for authorized content in the period
      article_ids = @scope.articles.pluck(:id)
      review_ids  = @scope.reviews.pluck(:id)
      wine_ids    = @scope.wines.pluck(:id)

      events = []
      [["Article", article_ids], ["Review", review_ids], ["Wine", wine_ids]].each do |type, ids|
        next if ids.empty?
        events += Analytics::Event.accepted
          .where(viewable_type: type, viewable_id: ids)
          .in_window(@period.start_at, @period.end_at)
          .pluck(:viewed_at, :identity)
      end

      # Bucket in Ruby
      buckets = edges.map do |start_at, end_at|
        bucket_events = events.select { |e| e[0] >= start_at && e[0] < end_at }
        bucket_views = bucket_events.size
        bucket_unique = bucket_events.map { |e| e[1] }.uniq.size

        {
          bucket_start: start_at.iso8601,
          bucket_end: end_at.iso8601,
          views: bucket_views,
          unique_viewers: bucket_unique,
        }
      end

      total_views = buckets.sum { |b| b[:views] }

      {
        buckets: buckets,
        total_views: total_views,
        grouping: grouping,
        period: @period.metadata.merge(scope: @scope.scope_label),
      }
    end

    private

    def empty_result
      {
        buckets: [],
        total_views: 0,
        grouping: "day",
        period: @period.metadata.merge(scope: @scope.scope_label),
      }
    end
  end
end