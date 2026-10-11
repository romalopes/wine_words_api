# Phase 7: Content detail aggregation service.
#
# Full metrics breakdown for a single authorized content item within the
# validated period. Includes time-series buckets when grouping=day|week,
# plus zero-view handling with denominator-zero flag.
#
# Returns a hash with all metrics, or nil if content not in scope.
module Analytics
  class ContentDetail
    GROUPINGS = %w[day week none].freeze

    def self.call(scope, period, content_type, content_id, params)
      new(scope, period, content_type, content_id, params).call
    end

    def initialize(scope, period, content_type, content_id, params)
      @scope = scope
      @period = period
      @content_type = content_type.to_s.classify
      @content_id = content_id.to_i
      @params = params
    end

    def call
      return nil if @period.empty?

      # Verify content is in scope
      content = @scope.detail_for(@content_type, @content_id)
      return nil unless content

      grouping = GROUPINGS.include?(@params[:grouping].to_s) ? @params[:grouping].to_s : "none"

      # Base metrics
      metrics = base_metrics(content)

      # Time-series buckets when grouping is requested
      if grouping != "none"
        metrics[:timeseries] = timeseries_buckets(content, grouping)
      end

      # Content metadata
      metrics.merge!(
        content_id: content.id,
        content_type: @content_type.downcase,
        title: content.respond_to?(:title) ? content.title : content.name,
        published_at: content.published_at&.iso8601,
        author_name: content.user&.display_name,
        period: @period.metadata.merge(scope: @scope.scope_label),
      )

      metrics
    end

    private

    def base_metrics(content)
      type = @content_type
      ids = [@content_id]

      views = Analytics::Event.accepted
        .where(viewable_type: type, viewable_id: ids)
        .in_window(@period.start_at, @period.end_at)
        .count

      unique_viewers = Analytics::Event.accepted
        .where(viewable_type: type, viewable_id: ids)
        .in_window(@period.start_at, @period.end_at)
        .distinct
        .count(:identity)

      likes = Like.where(likeable_type: type, likeable_id: ids)
        .where(created_at: @period.start_at...@period.end_at)
        .count

      comments = Comment.visible.top_level
        .where(commentable_type: type, commentable_id: ids)
        .where(created_at: @period.start_at...@period.end_at)
        .count

      replies = Comment.visible.where.not(parent_id: nil)
        .where(commentable_type: type, commentable_id: ids)
        .where(created_at: @period.start_at...@period.end_at)
        .count

      engagement_rate = if views.positive?
        ((likes + comments + replies).to_f / views * 100).round(2)
      else
        0.0
      end

      {
        views: views,
        unique_viewers: unique_viewers,
        likes: likes,
        comments: comments,
        replies: replies,
        engagement_rate: engagement_rate,
        engagement_denominator_zero: views.zero?,
      }
    end

    def timeseries_buckets(content, grouping)
      type = @content_type
      ids = [@content_id]

      # Build bucket edges
      bucket_seconds = grouping == "day" ? 1.day : 1.week
      edges = []
      cursor = @period.start_at
      while cursor < @period.end_at
        bucket_end = [cursor + bucket_seconds, @period.end_at].min
        edges << [cursor, bucket_end]
        cursor = bucket_end
      end

      # Load all events for this content in the period (accepted only)
      events = Analytics::Event.accepted
        .where(viewable_type: type, viewable_id: ids)
        .in_window(@period.start_at, @period.end_at)
        .order(:viewed_at)
        .pluck(:viewed_at, :identity)

      likes_data = Like.where(likeable_type: type, likeable_id: ids)
        .where(created_at: @period.start_at...@period.end_at)
        .order(:created_at)
        .pluck(:created_at, :user_id)

      comments_data = Comment.visible.top_level
        .where(commentable_type: type, commentable_id: ids)
        .where(created_at: @period.start_at...@period.end_at)
        .order(:created_at)
        .pluck(:created_at, :user_id)

      replies_data = Comment.visible.where.not(parent_id: nil)
        .where(commentable_type: type, commentable_id: ids)
        .where(created_at: @period.start_at...@period.end_at)
        .order(:created_at)
        .pluck(:created_at, :user_id)

      # Bucket in Ruby (small result sets per content item)
      edges.map do |start_at, end_at|
        bucket_events = events.select { |e| e[0] >= start_at && e[0] < end_at }
        bucket_likes = likes_data.select { |e| e[0] >= start_at && e[0] < end_at }
        bucket_comments = comments_data.select { |e| e[0] >= start_at && e[0] < end_at }
        bucket_replies = replies_data.select { |e| e[0] >= start_at && e[0] < end_at }

        bucket_views = bucket_events.size
        bucket_unique = bucket_events.map { |e| e[1] }.uniq.size
        bucket_likes_count = bucket_likes.size
        bucket_comments_count = bucket_comments.size
        bucket_replies_count = bucket_replies.size

        engagement = if bucket_views.positive?
          ((bucket_likes_count + bucket_comments_count + bucket_replies_count).to_f / bucket_views * 100).round(2)
        else
          0.0
        end

        {
          bucket_start: start_at.iso8601,
          bucket_end: end_at.iso8601,
          views: bucket_views,
          unique_viewers: bucket_unique,
          likes: bucket_likes_count,
          comments: bucket_comments_count,
          replies: bucket_replies_count,
          engagement_rate: engagement,
        }
      end
    end
  end
end