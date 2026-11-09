class Api::V1::ReviewsController < ApplicationController
  include Pundit::Authorization
  audit_actions :create, :update, :destroy

  # Lifetime of the cached #grouped payload (see the comment there): kept below
  # the presigned-URL window — 5 min expiry, signed 4 min ahead in
  # ImageAttributes — so cached responses never serve expired image URLs.
  GROUPED_CACHE_TTL = 2.minutes

  def log_description
    "#{audit_verb} review for \"#{@review&.vintage&.wine&.name}\""
  end

  def log_objects
    [ @review, @review&.vintage&.wine, @review&.vintage&.wine&.producer,
     @review&.user ].compact
  end

  before_action :authenticate_user!, except: [ :index, :show, :grouped, :related ]
  # Resolve @vintage for nested routes. Required for #create; optional for
  # #index (top-level feed runs without vintage params).
  # NOTE: declared ONCE — duplicate before_action declarations of the same
  # filter get merged by Rails and the last `only:`/`if:` silently wins.
  before_action :set_vintage,
                only: [ :create, :index ],
                if: -> { action_name == "create" || params[:vintage_id].present? }
  before_action :set_review, only: [ :show, :update, :destroy, :related ]

  def index
    # When nested under a wine/vintage, only that vintage's reviews apply;
    # otherwise fall back to all reviews. Content managers see everything
    # (including drafts); everyone else sees only what's visible to them.
    reviews =
      if @vintage
        @vintage.reviews
      else
        Review.all
      end

    # If advanced search filters are present, use the optimised EXISTS-based
    # search scope instead of chaining joins (which would duplicate rows when
    # combined with category/uncategorised filters).
    if advanced_search_filters.any?
      reviews = Review.advanced_search(advanced_search_filters)
    end

    reviews = policy_scope(reviews)
    # "My reviews" scope: narrow to the signed-in user's own reviews (any status,
    # including their drafts). `visible_to` already includes the user's own rows,
    # so this only tightens the set — it never widens what they can see.
    reviews = reviews.where(user: current_user) if params[:scope] == "mine" && current_user
    # Lifecycle filter (draft/published/archived). Whitelisted so an arbitrary
    # param can't inject SQL; blank/unknown values are ignored (no filter).
    reviews = reviews.where(status: params[:status]) if Review::STATUSES.include?(params[:status])
    reviews = reviews.eager_load({ user: :account }, vintage: :wine)
                     .preload(:categories, images: { file_attachment: :blob },
                               vintage: { wine: { images: { file_attachment: :blob } } })
    reviews = reviews.joins(:review_categories).where(review_categories: { category_id: params[:category_id] }).distinct if params[:category_id].present?
    reviews = reviews.left_outer_joins(:review_categories).where(review_categories: { id: nil }) if params[:uncategorised] == "true"
    reviews = reviews.where(source: params[:source]) if params[:source].present?
    reviews = apply_management_filters(reviews)
    # Full-text search + the requested ordering. `ordered_for_search` replaces
    # the scope's default ordering rather than appending to it, otherwise the
    # recency scope wins and relevance is silently ignored.
    term = search_term
    reviews = reviews.text_search(term)
                     .ordered_for_search(params[:sort], ranked: ranked_search?(term))
    # Paginate when the client asks for a page; otherwise return the full
    # legacy array (form pickers etc.).
    return if render_paginated(reviews) { |items| serialize_reviews(items) }

    render json: serialize_reviews(reviews)
  end

  # GET /api/v1/reviews/grouped?per_group=12&query=malbec&search=malbec
  # Server-side "12 reviews per category" view for the All Reviews page.
  # Applies the same visibility/query/search scoping as #index so the grouped
  # view and the paginated feed agree on what matches when no category is
  # selected.
  def grouped
    per_group = params[:per_group].to_i
    per_group = 12 if per_group <= 0
    per_group = per_group.clamp(1, 50)

    # Cold, this endpoint costs ~3.5s (window function over every review, eager
    # loads, per-blob R2 URL signing, serialization), so the assembled payload
    # is cached per viewer and per filter set. The viewer belongs in the key:
    # `visible_to` visibility, drafts and the `liked` state are baked into the
    # payload. The TTL stays below ImageAttributes' presigned-URL window so a
    # cached response never hands out expired image URLs — listings and like
    # state can lag by up to two minutes (the trade-off the categories #counts
    # payload already makes there, over 60 minutes).
    cache_key = [ "api/v1/reviews/grouped/v1", current_user&.id, per_group,
                  params[:scope], params[:status], search_term, params[:sort],
                  advanced_search_filters, request.base_url ]
    result = Rails.cache.fetch(cache_key, expires_in: GROUPED_CACHE_TTL) do
      grouped_payload(per_group)
    end

    render json: result
  end

  # The uncached body of #grouped: visibility-scoped rows capped per category
  # (with the window counts), eager-loaded once for the list serializer, and
  # ordered by each category's sort. Extracted so Rails.cache.fetch can wrap it.
  def grouped_payload(per_group)
    # If advanced search filters are present, use the optimised EXISTS-based
    # search scope (which doesn't duplicate rows) so category/uncategorised
    # filters can be applied on top without row explosion.
    scope = advanced_search_filters.any? ? Review.advanced_search(advanced_search_filters) : Review.all
    scope = scope.visible_to(current_user) unless current_user&.wine_manager?
    # "My reviews" scope: the signed-in user's own reviews (including their
    # drafts), so the "My Reviews" tab renders through this same capped, grouped
    # endpoint as "All Reviews" instead of shipping the author's entire,
    # unpaginated library via #my_reviews.
    scope = scope.where(user: current_user) if params[:scope] == "mine" && current_user
    # Lifecycle filter, applied before the per-category window so the "N per
    # category" cap and its counts reflect only the requested status.
    scope = scope.where(status: params[:status]) if Review::STATUSES.include?(params[:status])
    # Same search scoping as #index, including the `rank` column when the term
    # is searchable — the window function below orders each category's rows by
    # it, so "N most relevant per category" agrees with the paginated feed.
    term = search_term
    ranked = ranked_search?(term)
    scope = scope.text_search(term)
    # Whitelisted fragment qualified with the subquery alias (Review::SORT_ORDERS).
    order_sql = Review.search_order_sql(params[:sort], ranked: ranked, columns: "r.")

    # Cap each category at `per_group` rows with a window function. The outer
    # ORDER BY matters: the window's own ORDER BY only decides *which* rows are
    # numbered 1..N, Postgres does not guarantee any output order without it.
    rows = Review.find_by_sql([ <<~SQL, per_group ])
      SELECT sub.* FROM (
        SELECT r.id, r.created_at,
               COALESCE(rc.category_id, 0) AS grouped_cat_id,
               COUNT(*) OVER (PARTITION BY COALESCE(rc.category_id, 0)) AS grouped_count,
               ROW_NUMBER() OVER (
                 PARTITION BY COALESCE(rc.category_id, 0)
                 ORDER BY #{order_sql}
               ) AS rn
        FROM (#{scope.to_sql}) r
        LEFT JOIN review_categories rc ON rc.review_id = r.id
      ) sub
      WHERE sub.rn <= ?
      ORDER BY sub.grouped_cat_id, sub.rn
    SQL

    review_ids = rows.map(&:id).uniq
    reviews_by_id = Review.where(id: review_ids)
                      .eager_load({ user: :account }, vintage: :wine)
                      .preload(:categories, images: { file_attachment: :blob },
                               vintage: { wine: { images: { file_attachment: :blob } } })
                      .index_by(&:id)

    groups = Hash.new { |h, k| h[k] = [] }
    liked_ids = Likes.liked_ids_for(reviews_by_id.values, current_user)
    rows.each do |row|
      cat_id = row.grouped_cat_id == 0 ? nil : row.grouped_cat_id
      groups[cat_id] << ReviewListSerializer.new(reviews_by_id[row.id], request.base_url, liked_ids: liked_ids).as_json
    end

    # Window counts are calculated before the per-group limit, over the same
    # filtered rows. Reuse them instead of issuing separate count queries.
    category_counts = rows.to_h { |row| [ row.grouped_cat_id, row.grouped_count.to_i ] }
    uncategorised_count = category_counts.fetch(0, 0)

    categories = Category.where(id: groups.keys.compact).to_a
    ordered = categories.select { |c| c.sort_order_review.present? }.sort_by { |c| [ c.sort_order_review, c.name.to_s ] }
    unordered = categories.reject { |c| c.sort_order_review.present? }.sort_by { |c| c.name.to_s }

    result = (ordered + unordered).map do |cat|
      { category: cat.name, count: category_counts[cat.id] || groups[cat.id].size, reviews: groups[cat.id] }
    end

    if groups.key?(nil)
      result << { category: "Uncategorised", count: uncategorised_count, reviews: groups[nil] }
    end

    result
  end

  def serialize_reviews(reviews)
    liked_ids = Likes.liked_ids_for(reviews, current_user)
    reviews.map { |r| ReviewListSerializer.new(r, request.base_url, liked_ids: liked_ids).as_json }
  end

  def my_reviews
    # "My Reviews" list. Preload the associations the serializer reads
    # (`categories`, `images`) alongside the wine/vintage/user chain, otherwise
    # every review fires its own queries — an N+1 that dominated response time
    # for prolific reviewers. Ships the lean list serializer rather than the
    # full detail one: the toggle renders the same ReviewCard as the grouped and
    # paginated feeds, which need the tasting note preview but not the per-image
    # details. (`ReviewListSerializer` already emits wine_name,
    # wine_slug and vintage_year, so no manual merge is required.)
    reviews = Review.where(user: current_user)
                    .by_recency
                    .includes({ user: :account }, vintage: :wine)
                    .preload(:categories, images: { file_attachment: :blob })
    liked_ids = Likes.liked_ids_for(reviews, current_user)
    render json: reviews.map { |r| ReviewListSerializer.new(r, request.base_url, liked_ids: liked_ids).as_json }
  end

  def show
    if %w[draft archived].include?(@review.status) &&
       @review.user_id != current_user&.id &&
       !current_user&.wine_manager?
      return render json: { error: "Not found" }, status: :not_found
    end
    authorize @review
    render json: ReviewSerializer.new(@review, request.base_url, liked_ids: Likes.liked_ids_for([ @review ], current_user)).as_json
  end

  # GET /api/v1/reviews/:id/related?limit=5
  # The "more reviews" footer on the review page: the newest reviews from the same
  # categories as this one, the current review excluded. See Api::RelatedFeed for
  # how the slots are dealt when the review sits in several categories, and for
  # the uncategorised fallback (the newest reviews overall).
  def related
    limit = related_limit

    # Fetch a few more than `limit` per category so that excluding the current
    # review (and the dedup across categories) cannot leave the list short.
    per_category = [ limit, 5 ].min + 1
    base = Review.where.not(id: @review.id)
    base = base.visible_to(current_user) unless current_user&.wine_manager?
    # `ReviewSerializer` (unlike the list serializer) also renders the tasting
    # note the footer previews, and reads the vintage/wine/categories.
    base = base.includes({ user: :account }, :categories, :vintage, images: { file_attachment: :blob })

    buckets = related_buckets(
      @review, base,
      join: ReviewCategory, foreign_key: :review_id,
      per_category: per_category, limit: limit
    )

    reviews = round_robin(buckets, limit)
    liked_ids = Likes.liked_ids_for(reviews, current_user)
    # `{}` and not `do...end`: the block would bind to `render` (lower
    # precedence) instead of to `map`, and the raw records would be serialized.
    payload = reviews.map do |review|
      ReviewSerializer.new(review, request.base_url, liked_ids: liked_ids).as_json
    end
    render json: payload
  end

  def create
    review = @vintage.reviews.new(review_params)
    @review = review
    review.user = current_user
    authorize @review

    if review.title.blank?
      year = @vintage.no_vintage? ? "NV" : @vintage.year
      review.title = "#{@vintage.wine.name} #{year}"
    end

    if review.save
      publish_review_events(review)
      render json: ReviewSerializer.new(review, request.base_url, liked_ids: Likes.liked_ids_for([ review ], current_user)).as_json, status: :created
    else
      render json: { errors: review.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize @review

    if @review.update(review_params)
      publish_review_events(@review)
      if request.headers["Prefer"] == "return=minimal"
        response.set_header("Preference-Applied", "return=minimal")
        return head :no_content
      end

      render json: ReviewSerializer.new(@review, request.base_url, liked_ids: Likes.liked_ids_for([ @review ], current_user)).as_json
    else
      render json: { errors: @review.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @review
    @review.destroy
    head :no_content
  end

  private

  # Management-list filters run after the existing visibility scope. They can
  # only narrow the set of records a caller can already see, never reveal
  # another author's drafts to an ordinary account.
  # Extract and cast advanced search filter parameters. Returns a hash suitable
  # for Review.advanced_search. Keys with blank values are omitted so the
  # model scope can skip them.
  def advanced_search_filters
    p = params
    filters = {
      q: p[:q].presence,
      name: p[:name].presence,
      producer_name: p[:producer_name].presence,
      color: p[:color].presence,
      closure: p[:closure].presence,
      sparkling: boolean_param(:sparkling),
      fortified: boolean_param(:fortified),
      country_id: integer_param(:country_id),
      region_ids: integer_array_param(:region_ids),
      grape_ids: integer_array_param(:grape_ids),
      alcohol_min: float_param(:alcohol_min),
      alcohol_max: float_param(:alcohol_max),
      vintage_year_min: integer_param(:vintage_year_min),
      vintage_year_max: integer_param(:vintage_year_max),
      price_min: float_param(:price_min),
      price_max: float_param(:price_max),
      score_min: float_param(:score_min),
      score_max: float_param(:score_max),
      published_from: date_param(:published_from),
      published_to: date_param(:published_to),
      drink_from_min: integer_param(:drink_from_min),
      drink_from_max: integer_param(:drink_from_max),
      drink_to_min: integer_param(:drink_to_min),
      drink_to_max: integer_param(:drink_to_max),
      taste_parameters: taste_parameter_filters
    }.compact

    filters.empty? ? {} : filters
  end

  # Boolean array param helper for grape_ids, region_ids, etc.
  def integer_array_param(key)
    return nil if params[key].blank?
    Array(params[key]).map { |v| Integer(v, exception: false) }.compact.presence
  end

  # Taste parameter filters: { acidity: { min: 3, max: 7 }, ... }
  def taste_parameter_filters
    return nil if params[:taste_parameters].blank?
    tp = params[:taste_parameters]
    return nil unless tp.is_a?(ActionController::Parameters) || tp.is_a?(Hash)

    permitted = tp.permit(TASTE_SLUGS.map { |s| { s => [:min, :max] } })
    result = {}
    TASTE_SLUGS.each do |slug|
      next unless permitted[slug].present?
      range = permitted[slug]
      min = integer_param_from_hash(range, :min)
      max = integer_param_from_hash(range, :max)
      next if min.nil? && max.nil?
      result[slug] = { min: min, max: max }.compact
    end
    result.empty? ? nil : result
  end

  def integer_param_from_hash(hash, key)
    return nil unless hash[key].present?
    Integer(hash[key], exception: false)
  end

  TASTE_SLUGS = %w[
    acidity
    alcohol-warmth
    body
    fruit-intensity
    sweetness
    tannin
  ].freeze

  # Parameter casting helpers (mirrored from WinesController).
  def boolean_param(key)
    return nil if params[key].blank?

    ActiveModel::Type::Boolean.new.cast(params[key])
  end

  def integer_param(key)
    return nil if params[key].blank?

    Integer(params[key], exception: false)
  end

  def float_param(key)
    return nil if params[key].blank?

    Float(params[key], exception: false)
  end

  def date_param(key)
    return nil if params[key].blank?

    Date.parse(params[key].to_s)
  rescue ArgumentError
    nil
  end

  def apply_management_filters(scope)
    scope = scope.where(user: current_user) if params[:scope] == "mine" && current_user
    scope = scope.where(status: params[:status]) if Review::STATUSES.include?(params[:status])

    case params[:deadline]
    when "overdue"
      scope.where(status: "draft").where("deadline < ?", Date.current)
    when "due_soon"
      scope.where(status: "draft", deadline: Date.current..(Date.current + 7))
    when "none"
      scope.where(deadline: nil)
    when "has"
      scope.where.not(deadline: nil)
    else
      scope
    end
  end

  # The listing's single search term. `search` is the deprecated spelling of
  # `query`: the two parameters used to run different code — `query` did a
  # title/wine ILIKE while `search` hit the weighted tsvector — so the UI never
  # reached full-text search at all. One term now filters *and* ranks.
  def search_term
    params[:query].presence || params[:search].presence
  end

  # Whether the request's term is searchable, i.e. whether `text_search`
  # filtered and selected a `rank` column worth ordering by. Terms shorter than
  # TextSearchable::MIN_TERM_LENGTH are not searchable, which leaves the
  # listing unfiltered instead of returning an empty page.
  def ranked_search?(term)
    Review.searchable_term(term).present?
  end

  # Follow notifications (issue #192): first publication and meaningful edits
  # of a published review are events. A draft→published transition is the
  # publication event even when other fields changed too (no double notify);
  # draft edits, deadline-only changes and status-only unpublish never notify.
  def publish_review_events(review)
    if review.saved_change_to_status? && review.status == "published"
      Notifications::EventPublisher.publish!(
        event_type: "review.published", subject: review, actor: current_user
      )
    elsif review.status == "published" &&
          Notifications::MeaningfulChangeDetector.meaningful_update?(review)
      Notifications::EventPublisher.publish!(
        event_type: "review.updated", subject: review, actor: current_user
      )
    end
  end

  def set_vintage
    wine = Wine.find_by!(slug: params[:wine_id])
    @vintage = wine.vintages.find(params[:vintage_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Vintage not found" }, status: :not_found
  end

  def set_review
    @review = Review.includes({ user: :account },
                              images: { file_attachment: :blob },
                              vintage: { wine: { images: { file_attachment: :blob } } })
                    .find_by(slug: params[:id]) ||
              Review.includes({ user: :account },
                              images: { file_attachment: :blob },
                              vintage: { wine: { images: { file_attachment: :blob } } }).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Review not found" }, status: :not_found
  end

  def review_params
    params.require(:review).permit(:comment, :score, :status, :published_at, :title,
                                   :vintage_id, :source, :deadline,
                                   :drink_from, :drink_to, :drink_plus, images: [],
                                   category_ids: [])
  end
end
