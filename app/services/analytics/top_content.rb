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

    def load_all_content(include_zero)
      content_items = []
      # Articles
      article_objects = []
      article_ids = []
      @scope.articles.find_each do |article|
        article_objects << article
        article_ids << article.id
      end
      article_metrics = aggregate_content_metrics("Article", article_ids)
      article_objects.each do |article|
        metrics = article_metrics[article.id] || zero_metrics
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
      review_objects = []
      review_ids = []
      @scope.reviews.find_each do |review|
        review_objects << review
        review_ids << review.id
      end
      review_metrics = aggregate_content_metrics("Review", review_ids)
      review_objects.each do |review|
        metrics = review_metrics[review.id] || zero_metrics
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
      wine_objects = []
      wine_ids = []
      @scope.wines.find_each do |wine|
        wine_objects << wine
        wine_ids << wine.id
      end
      wine_metrics = aggregate_content_metrics("Wine", wine_ids)
      wine_objects.each do |wine|
        metrics = wine_metrics[wine.id] || zero_metrics
        next if metrics[:views].zero? && !include_zero
        content_items << metrics.merge(
          content_id: wine.id,
          content_type: "wine",
          title: wine.name,
          published_at: wine.created_at&.iso8601,
          author_name: nil,
        )
      end
      content_items
    end

    def aggregate_content_metrics(type, ids)
      return {} if ids.empty?
      views = Analytics::Event.accepted.where(viewable_type: type, viewable_id: ids).in_window(@period.start_at, @period.end_at).group(:viewable_id).count
      unique_viewers = Analytics::Event.accepted.where(viewable_type: type, viewable_id: ids).in_window(@period.start_at, @period.end_at).group(:viewable_id).distinct.count(:identity)
      likes = Like.where(likeable_type: type, likeable_id: ids).where(created_at: @period.start_at...@period.end_at).group(:likeable_id).count
      comments = Comment.visible.top_level.where(commentable_type: type, commentable_id: ids).where(created_at: @period.start_at...@period.end_at).group(:commentable_id).count
      replies = Comment.visible.where.not(parent_id: nil).where(commentable_type: type, commentable_id: ids).where(created_at: @period.start_at...@period.end_at).group(:commentable_id).count
      map = {}
      ids.each do |id|
        map[id] = { views: views[id] || 0, unique_viewers: unique_viewers[id] || 0, likes: likes[id] || 0, comments: comments[id] || 0, replies: replies[id] || 0, engagement_rate: 0.0 }
      end
      map.each do |id, m|
        v = m[:views]
        # Compatibility field name: this is engagement actions per 100 views,
        # not a conventional percentage rate.
        m[:engagement_rate] = v.positive? ? ((m[:likes] + m[:comments] + m[:replies]).to_f / v * 100).round(2) : 0.0
      end
      map
    end

    def zero_metrics
      { views: 0, unique_viewers: 0, likes: 0, comments: 0, replies: 0, engagement_rate: 0.0 }
    end

    def sort_content(items, sort, dir)
      items.sort_by do |item|
        val = item[sort.to_sym] || 0
        dir == "asc" ? val : -val
      end
    end
  end
end