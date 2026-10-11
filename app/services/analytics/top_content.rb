# Phase 7: Top content aggregation service.
#
# Ranks authorized content by views (default) or engagement within the
# validated period. Supports pagination, deterministic sorting, and
# include-zero-views content when requested.
#
# Returns { rows: [...], total: Integer, period: {...} }
module Analytics
  class TopContent
    SORTS = %w[views unique_viewers likes comments engagement_rate published_at].freeze
    DIRECTIONS = %w[asc desc].freeze

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

      sort    = SORTS.include?(@params[:sort].to_s) ? @params[:sort].to_s : "views"
      dir     = DIRECTIONS.include?(@params[:direction].to_s) ? @params[:direction].to_s : "desc"
      page    = [@params[:page].to_i, 1].max
      per_page = [@params[:per_page].to_i, 1].max.clamp(1, 100)
      include_zero = @params[:include_zero_views].present?

      # Load all authorized content with pre-aggregated metrics
      all_content = load_all_content(include_zero)

      # Apply sorting
      sorted = sort_content(all_content, sort, dir)

      # Pagination
      total = sorted.size
      offset = (page - 1) * per_page
      rows = sorted[offset, per_page] || []

      {
        rows: rows,
        total: total,
        page: page,
        per_page: per_page,
        sort: sort,
        direction: dir,
        period: @period.metadata.merge(scope: @scope.scope_label),
      }
    end

    private

    def empty_result
      {
        rows: [],
        total: 0,
        page: 1,
        per_page: 20,
        sort: "views",
        direction: "desc",
        period: @period.metadata.merge(scope: @scope.scope_label),
      }
    end

    # Load all authorized content with their metrics pre-aggregated.
    # Returns an array of hashes, one per content item.
    def load_all_content(include_zero)
      content_items = []

      # Articles
      @scope.articles.find_each do |article|
        metrics = content_metrics(article, "Article")
        next if metrics[:views].zero? && !include_zero
        content_items << metrics.merge(
          content_id: article.id,
          content_type: "article",
          title: article.title,
          published_at: article.published_at&.iso8601,
          author_name: article.user&.display_name,
        )
      end

      # Reviews
      @scope.reviews.find_each do |review|
        metrics = content_metrics(review, "Review")
        next if metrics[:views].zero? && !include_zero
        content_items << metrics.merge(
          content_id: review.id,
          content_type: "review",
          title: review.title,
          published_at: review.published_at&.iso8601,
          author_name: review.user&.display_name,
        )
      end

      # Wines
      @scope.wines.find_each do |wine|
        metrics = content_metrics(wine, "Wine")
        next if metrics[:views].zero? && !include_zero
        content_items << metrics.merge(
          content_id: wine.id,
          content_type: "wine",
          title: wine.name,
          published_at: wine.published_at&.iso8601,
          author_name: wine.user&.display_name,
        )
      end

      content_items
    end

    # Pre-aggregate all metrics for a single content item.
    # Returns a hash with views, unique_viewers, likes, comments, replies, engagement_rate.
    def content_metrics(content, type)
      ids = [content.id]

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
      }
    end

    def sort_content(items, sort, dir)
      items.sort_by do |item|
        val = item[sort.to_sym] || 0
        dir == "asc" ? val : -val
      end
    end
  end
end