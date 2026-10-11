# Phase 7: Summary aggregation service.
#
# Single-row roll-up for the authorized content set within the validated
# period. All distinct counts are pre-aggregated to avoid Cartesian
# multiplication when joining views/likes/comments.
#
# Returns a plain Hash (no AR objects) so callers can render JSON directly.
module Analytics
  class Summary
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

      # Pre-aggregate each metric independently
      views_agg      = views_aggregation
      viewers_agg    = unique_viewers_aggregation
      likes_agg      = likes_aggregation
      comments_agg   = comments_aggregation
      replies_agg    = replies_aggregation

      views       = views_agg[:count]
      unique_viewers = viewers_agg[:count]
      likes       = likes_agg[:count]
      comments    = comments_agg[:count]
      replies     = replies_agg[:count]

      # Engagement rate = (likes + comments + replies) / views
      # Returns 0.0 with a flag when views == 0 to avoid NaN/Infinity.
      if views.positive?
        engagement_rate = ((likes + comments + replies).to_f / views * 100).round(2)
        denominator_zero = false
      else
        engagement_rate = 0.0
        denominator_zero = true
      end

      {
        views: views,
        unique_viewers: unique_viewers,
        likes: likes,
        comments: comments,
        replies: replies,
        engagement_rate: engagement_rate,
        engagement_denominator_zero: denominator_zero,
        content_count: content_count,
        period: @period.metadata.merge(scope: @scope.scope_label),
      }
    end

    private

    def empty_result
      {
        views: 0,
        unique_viewers: 0,
        likes: 0,
        comments: 0,
        replies: 0,
        engagement_rate: 0.0,
        engagement_denominator_zero: true,
        content_count: 0,
        period: @period.metadata.merge(scope: @scope.scope_label),
      }
    end

    def content_count
      @scope.articles.count + @scope.reviews.count + @scope.wines.count
    end

    # Helper: build an array of three sub-scopes (Article, Review, Wine) and
    # sum the results. This avoids complex polymorphic Arel while keeping
    # queries decoupled and cacheable.
    def sum_across_content_types(query_block)
      [
        query_block.call("Article", @scope.articles.pluck(:id)),
        query_block.call("Review",  @scope.reviews.pluck(:id)),
        query_block.call("Wine",    @scope.wines.pluck(:id)),
      ].sum { |r| r[:count] }
    end

    # Views aggregation — total accepted events in window.
    def views_aggregation
      { count: sum_across_content_types(->(type, ids) {
        return { count: 0 } if ids.empty?
        Analytics::Event.accepted
          .where(viewable_type: type, viewable_id: ids)
          .in_window(@period.start_at, @period.end_at)
          .count
      }) }
    end

    # Unique viewers — distinct identities (account:X + visitor:Y) in window.
    def unique_viewers_aggregation
      { count: sum_across_content_types(->(type, ids) {
        return { count: 0 } if ids.empty?
        Analytics::Event.accepted
          .where(viewable_type: type, viewable_id: ids)
          .in_window(@period.start_at, @period.end_at)
          .distinct
          .count(:identity)
      }) }
    end

    # Likes — count of Like rows on authorized content, created within the window.
    # Note: Like.created_at is used (not analytics_events.viewed_at) because
    # likes are explicit actions with their own timestamp.
    def likes_aggregation
      { count: sum_across_content_types(->(type, ids) {
        return { count: 0 } if ids.empty?
        Like.where(likeable_type: type, likeable_id: ids)
          .where(created_at: @period.start_at...@period.end_at)
          .count
      }) }
    end

    # Comments — visible (not soft-deleted) top-level comments on authorized content.
    def comments_aggregation
      { count: sum_across_content_types(->(type, ids) {
        return { count: 0 } if ids.empty?
        Comment.visible
          .top_level
          .where(commentable_type: type, commentable_id: ids)
          .where(created_at: @period.start_at...@period.end_at)
          .count
      }) }
    end

    # Replies — visible child comments on authorized content.
    def replies_aggregation
      { count: sum_across_content_types(->(type, ids) {
        return { count: 0 } if ids.empty?
        Comment.visible
          .where.not(parent_id: nil)
          .where(commentable_type: type, commentable_id: ids)
          .where(created_at: @period.start_at...@period.end_at)
          .count
      }) }
    end
  end
end