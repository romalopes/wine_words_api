class Api::V1::ArticlesController < ApplicationController
  include Pundit::Authorization
  audit_actions :create, :update, :destroy

  def log_description
    "#{audit_verb} article \"#{@article.title}\""
  end

  def log_objects
    [ @article ].compact
  end

  before_action :authenticate_user!, except: [ :index, :show, :grouped, :related ]
  before_action :set_article, only: [ :show, :update, :destroy, :related ]
  def index
    # `:categories` (through) and `:images` rather than the join rows alone:
    # the list serializer reads `article.categories`, and a through-association
    # is not satisfied by preloading `article_categories`, so each card used to
    # issue its own queries.
    articles = Article.recent.eager_load(user: :account)
                      .preload(:categories, images: { file_attachment: :blob })
    # Content managers see everything (including drafts); everyone else sees
    # only what's visible to them (published + their own drafts).
    articles = policy_scope(articles)
    articles = articles.joins(:article_categories).where(article_categories: { category_id: params[:category_id] }).distinct if params[:category_id].present?
    articles = articles.left_outer_joins(:article_categories).where(article_categories: { id: nil }) if params[:uncategorised] == "true"
    articles = articles.where(source: params[:source]) if params[:source].present?
    articles = apply_management_filters(articles)
    # Full-text search (title, abstract, body, tags, category, author) plus the
    # requested ordering. `ordered_for_search` replaces `recent` instead of
    # appending to it, otherwise recency wins and relevance is silently ignored.
    term = search_term
    # Trigger similarity search for `q` (advanced search) parameter
    if params[:q].present?
      # Use similarity search for advanced search (fuzzy matching)
      # similarity search already orders by GREATEST similarity score
      articles = search_with_similarities
    else
      articles = articles.text_search(term)
                       .ordered_for_search(params[:sort], ranked: ranked_search?(term))
    end
    return if render_paginated(articles) { |items| serialize_articles(items) }

    render json: serialize_articles(articles)
  end

  def serialize_articles(articles)
    liked_ids = Likes.liked_ids_for(articles, current_user)
    articles.map { |a| ArticleListSerializer.new(a, request.base_url, liked_ids: liked_ids).as_json }
  end

  # GET /api/v1/articles/grouped?per_group=12&query=barolo&search=barolo
  # Server-side "12 articles per category" view for the All Articles page.
  # Applies the same visibility/query/search scoping as #index so the grouped
  # view and the paginated feed agree on what matches when no category is
  # selected.
  def grouped
    per_group = params[:per_group].to_i
    per_group = 12 if per_group <= 0
    per_group = per_group.clamp(1, 50)

    scope = Article.all
    scope = scope.visible_to(current_user) unless current_user&.wine_manager?
    # Lifecycle filter (draft/published/archived), applied before the
    # per-category window so the "N per category" cap and its counts reflect
    # only the requested status.
    scope = scope.where(status: params[:status]) if Article::STATUSES.include?(params[:status])
    # Same search scoping as #index, including the `rank` column when the term
    # is searchable — the window function below orders each category's rows by
    # it, so "N most relevant per category" agrees with the paginated feed.
    term = search_term
    # Trigger similarity search for `q` (advanced search) parameter
    if params[:q].present?
      # Use similarity search for advanced search (fuzzy matching)
      scope = search_with_similarities(skip_eager_load: true)
      # For similarity search, use the GREATEST similarity ordering directly
      # instead of the rank-based ordering from search_order_sql
      order_sql = <<~SQL.squish
        GREATEST(
          similarity(a.title, #{ActiveRecord::Base.connection.quote(term)}),
          similarity(a.body, #{ActiveRecord::Base.connection.quote(term)}),
          COALESCE((SELECT MAX(similarity(r.title, #{ActiveRecord::Base.connection.quote(term)}))
                    FROM article_reviews ar JOIN reviews r ON r.id = ar.review_id
                    WHERE ar.article_id = a.id AND r.status = 'published'), 0),
          COALESCE((SELECT MAX(similarity(r.comment, #{ActiveRecord::Base.connection.quote(term)}))
                    FROM article_reviews ar JOIN reviews r ON r.id = ar.review_id
                    WHERE ar.article_id = a.id AND r.status = 'published'), 0),
          COALESCE((SELECT MAX(similarity(w.name, #{ActiveRecord::Base.connection.quote(term)}))
                    FROM article_vintages av JOIN vintages v ON v.id = av.vintage_id
                    JOIN wines w ON w.id = v.wine_id
                    WHERE av.article_id = a.id), 0),
          COALESCE((SELECT MAX(similarity(p.name, #{ActiveRecord::Base.connection.quote(term)}))
                    FROM article_producers ap JOIN producers p ON p.id = ap.producer_id
                    WHERE ap.article_id = a.id), 0),
          word_similarity(a.title, #{ActiveRecord::Base.connection.quote(term)}) * 0.8
        ) DESC
      SQL
    else
      ranked = ranked_search?(term)
      scope = scope.text_search(term)
      # Whitelisted fragment qualified with the subquery alias (Article::SORT_ORDERS).
      order_sql = Article.search_order_sql(params[:sort], ranked: ranked, columns: "a.")
    end

    # Cap each category at `per_group` rows with a window function. The outer
    # ORDER BY matters: the window's own ORDER BY only decides *which* rows are
    # numbered 1..N, Postgres does not guarantee any output order without it.
    rows = Article.find_by_sql([ <<~SQL, per_group ])
      SELECT sub.* FROM (
        SELECT DISTINCT a.id, a.title, a.abstract, a.status,
               a.user_id, a.created_at, a.updated_at,
               COALESCE(ac.category_id, 0) AS grouped_cat_id,
               COUNT(*) OVER (PARTITION BY COALESCE(ac.category_id, 0)) AS grouped_count,
               ROW_NUMBER() OVER (
                 PARTITION BY COALESCE(ac.category_id, 0)
                 ORDER BY #{order_sql}
               ) AS rn
        FROM (#{scope.to_sql}) a
        LEFT JOIN article_categories ac ON ac.article_id = a.id
      ) sub
      WHERE sub.rn <= ?
      ORDER BY sub.grouped_cat_id, sub.rn
    SQL

    article_ids = rows.map(&:id).uniq
    articles_by_id = Article.where(id: article_ids)
                        .eager_load(user: :account).preload(:categories, images: { file_attachment: :blob })
                        .index_by(&:id)

    groups = Hash.new { |h, k| h[k] = [] }
    liked_ids = Likes.liked_ids_for(articles_by_id.values, current_user)
    rows.each do |row|
      cat_id = row.grouped_cat_id == 0 ? nil : row.grouped_cat_id
      groups[cat_id] << ArticleListSerializer.new(articles_by_id[row.id], request.base_url, liked_ids: liked_ids).as_json
    end

    category_counts = rows.to_h { |row| [ row.grouped_cat_id, row.grouped_count.to_i ] }
    uncategorised_count = category_counts.fetch(0, 0)

    categories = Category.where(id: groups.keys.compact).to_a
    ordered = categories.select { |c| c.sort_order_article.present? }.sort_by { |c| [ c.sort_order_article, c.name.to_s ] }
    unordered = categories.reject { |c| c.sort_order_article.present? }.sort_by { |c| c.name.to_s }

    result = (ordered + unordered).map do |cat|
      { category: cat.name, count: category_counts[cat.id] || groups[cat.id].size, articles: groups[cat.id] }
    end

    if groups.key?(nil)
      result << { category: "Uncategorised", count: uncategorised_count, articles: groups[nil] }
    end

    render json: result
  end

  # Articles belonging to the signed-in user (including drafts), used by the
  # "My Articles" toggle on the Articles page.
  def my_articles
    articles = Article.where(user: current_user).recent.includes({ user: :account }, :category, :tags, :wines, :producers)
    liked_ids = Likes.liked_ids_for(articles, current_user)
    render json: articles.map { |a| ArticleSerializer.new(a, request.base_url, liked_ids: liked_ids).as_json }
  end

  def show
    if %w[draft archived].include?(@article.status) &&
       @article.user_id != current_user&.id &&
       !current_user&.wine_manager?
      return render json: { error: "Not found" }, status: :not_found
    end
    authorize @article

    ActiveRecord::Associations::Preloader.new(
      records: [ @article ],
      associations: [ :tags, :producers, :categories, :article_reviews,
                      { vintages: { wine: :regions } },
                      { reviews: [ { user: :account }, { vintage: :wine } ] } ]
    ).call
    image_records = [ @article ] + @article.reviews.to_a +
                    @article.reviews.filter_map { |review| review.vintage&.wine }
    ActiveRecord::Associations::Preloader.new(
      records: image_records.uniq, associations: :images,
      scope: Image.eager_load(file_attachment: :blob)
    ).call

    render json: ArticleSerializer.new(
      @article,
      request.base_url,
      liked_ids: Likes.liked_ids_for([ @article ], current_user),
      # Fetched separately from the article's: `liked_ids_for` returns one
      # type's ids, and mixing articles with reviews in one collection would
      # return whichever type came first.
      review_liked_ids: Likes.liked_ids_for(@article.reviews, current_user)
    ).as_json
  end

  # GET /api/v1/articles/:id/related?limit=5
  # The "more articles" footer on the article page: the newest articles from the
  # same categories as this one, the current article excluded.
  #
  # When the article sits in several categories the slots are dealt round-robin
  # (A1, B1, A2, B2, A3) rather than taking the 5 newest of the first category.
  # The rows are still the newest ones overall — the interleave only stops a
  # single category from taking every slot. An UNCATEGORISED article has no
  # categories to draw from, so it falls back to the newest articles overall.
  def related
    limit = related_limit

    # Fetch a few more than `limit` per category so that excluding the current
    # article (and the dedup across categories) cannot leave the list short.
    per_category = [ limit, 5 ].min + 1
    base = Article.where.not(id: @article.id)
    base = base.visible_to(current_user) unless current_user&.wine_manager?
    base = base.includes({ user: :account }, images: { file_attachment: :blob })

    buckets = related_buckets(
      @article, base,
      join: ArticleCategory, foreign_key: :article_id,
      per_category: per_category, limit: limit
    )

    render json: serialize_articles(round_robin(buckets, limit))
  end

  def create
    @article = Article.new(article_params)
    @article.user = current_user
    authorize @article
    if @article.save
      image_errors = attach_images(@article)
      if image_errors.any?
        return render json: { errors: image_errors }, status: :unprocessable_entity
      end

      publish_article_events(@article)
      render json: ArticleSerializer.new(@article, request.base_url, liked_ids: Likes.liked_ids_for([ @article ], current_user)).as_json, status: :created
    else
      render json: { errors: @article.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize @article

    if @article.update(article_params)
      image_errors = attach_images(@article)
      if image_errors.any?
        return render json: { errors: image_errors }, status: :unprocessable_entity
      end

      publish_article_events(@article)
      if request.headers["Prefer"] == "return=minimal"
        response.set_header("Preference-Applied", "return=minimal")
        return head :no_content
      end

      render json: ArticleSerializer.new(@article, request.base_url, liked_ids: Likes.liked_ids_for([ @article ], current_user)).as_json
    else
      render json: { errors: @article.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @article
    @article.destroy
    head :no_content
  end

  private

  # Similarity-based search using PostgreSQL pg_trgm functions.
  # sim_threshold = 0.2 ensures fuzzy matching
  # word_sim_threshold = 0.3 ensures word-level matching
  # @param skip_eager_load [Boolean] if true, skip eager_load/preload for subquery compatibility
  def search_with_similarities(skip_eager_load: false)
    # Accept either `q` (advanced search) or `query` (simple search) parameter
    query = (params[:q].presence || params[:query].presence || "").to_s.strip
    return if query.blank?

    sim_threshold = 0.2
    word_sim_threshold = 0.3
    quoted_query = ActiveRecord::Base.connection.quote(query)

    scope = Article.visible_to(current_user) || Article.all
    scope = scope.where(user: current_user) if params[:scope] == "mine" && current_user
    scope = scope.where(status: params[:status]) if Article::STATUSES.include?(params[:status])
    unless skip_eager_load
      scope = scope.eager_load(user: :account)
                       .preload(:tags, images: { file_attachment: :blob },
                                reviews: { vintage: { wine: { images: { file_attachment: :blob } } } },
                                vintages: { wine: { images: { file_attachment: :blob } } },
                                producers: { images: { file_attachment: :blob } })
    end

    # Build WHERE conditions using trigram similarity
    # Match against title, body, linked review titles/contents, wine names, producer names
    conditions = [
      "similarity(title, ?) > ?",
      "similarity(body, ?) > ?",
      "EXISTS (SELECT 1 FROM article_reviews ar JOIN reviews r ON r.id = ar.review_id " +
        "WHERE ar.article_id = articles.id AND r.status = 'published' " +
        "AND (similarity(r.title, ?) > ? OR similarity(r.comment, ?) > ?))",
      "EXISTS (SELECT 1 FROM article_vintages av JOIN vintages v ON v.id = av.vintage_id " +
        "JOIN wines w ON w.id = v.wine_id " +
        "WHERE av.article_id = articles.id " +
        "AND similarity(w.name, ?) > ?)",
      "EXISTS (SELECT 1 FROM article_producers ap JOIN producers p ON p.id = ap.producer_id " +
        "WHERE ap.article_id = articles.id " +
        "AND similarity(p.name, ?) > ?)",
      "word_similarity(title, ?) > ?"
    ].join(" OR ")

    scope = scope.where(conditions,
      query, sim_threshold,
      query, sim_threshold,
      query, sim_threshold,
      query, sim_threshold,
      query, sim_threshold,
      query, sim_threshold,
      query, word_sim_threshold
    )

    # Order by the best similarity match across all fields
    order_sql = "GREATEST(" +
      "similarity(title, " + quoted_query + ")," +
      "similarity(body, " + quoted_query + ")," +
      "COALESCE((SELECT MAX(similarity(r.title, " + quoted_query + ")) " +
        "FROM article_reviews ar JOIN reviews r ON r.id = ar.review_id " +
        "WHERE ar.article_id = articles.id AND r.status = 'published'), 0)," +
      "COALESCE((SELECT MAX(similarity(r.comment, " + quoted_query + ")) " +
        "FROM article_reviews ar JOIN reviews r ON r.id = ar.review_id " +
        "WHERE ar.article_id = articles.id AND r.status = 'published'), 0)," +
      "COALESCE((SELECT MAX(similarity(w.name, " + quoted_query + ")) " +
        "FROM article_vintages av JOIN vintages v ON v.id = av.vintage_id " +
        "JOIN wines w ON w.id = v.wine_id " +
        "WHERE av.article_id = articles.id), 0)," +
      "COALESCE((SELECT MAX(similarity(p.name, " + quoted_query + ")) " +
        "FROM article_producers ap JOIN producers p ON p.id = ap.producer_id " +
        "WHERE ap.article_id = articles.id), 0)," +
      "word_similarity(title, " + quoted_query + ") * 0.8" +
      ") DESC"

    scope = scope.order(Arel.sql(order_sql))

    scope
  end

  # Management-list filters run after the existing visibility scope. They can
  # only narrow the set of records a caller can already see, never reveal
  # another author's drafts to an ordinary account.
  def apply_management_filters(scope)
    scope = scope.where(user: current_user) if params[:scope] == "mine" && current_user
    scope = scope.where(status: params[:status]) if Article::STATUSES.include?(params[:status])

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
  # title-only ILIKE while `search` hit the weighted tsvector — so the UI never
  # reached full-text search at all. One term now filters *and* ranks.
  def search_term
    params[:query].presence || params[:search].presence
  end

  # Whether the request's term is searchable, i.e. whether `text_search`
  # filtered and selected a `rank` column worth ordering by. Terms shorter than
  # TextSearchable::MIN_TERM_LENGTH are not searchable, which leaves the
  # listing unfiltered instead of returning an empty page.
  def ranked_search?(term)
    Article.searchable_term(term).present?
  end

  # Keep lookup lightweight; show loads its associations after authorization.
  def set_article
    scope = Article.eager_load(user: :account)
    @article = scope.find_by(slug: params[:id]) || scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Article not found" }, status: :not_found
  end

  def attach_images(article)
    files = params[:article]&.delete(:images)
    return [] unless files.present?

    Array(files).compact_blank.flat_map do |file|
      img = Image.new(imageable: article)
      img.file.attach(file)
      img.save
      img.errors.full_messages
    end
  end

  # Follow notifications (issue #192): first publication and meaningful edits
  # of a published article are events. A draft→published transition is the
  # publication event even when other fields changed too (no double notify);
  # draft edits, deadline-only changes and status-only unpublish never notify.
  def publish_article_events(article)
    if article.saved_change_to_status? && article.status == "published"
      Notifications::EventPublisher.publish!(
        event_type: "article.published", subject: article, actor: current_user
      )
    elsif article.status == "published" &&
          Notifications::MeaningfulChangeDetector.meaningful_update?(article)
      Notifications::EventPublisher.publish!(
        event_type: "article.updated", subject: article, actor: current_user
      )
    end
  end

  def article_params
    permitted = params.require(:article).permit(
      :title, :abstract, :body, :status, :published_at, :source, :deadline,
      :tag_names, vintage_ids: [], review_ids: [], producer_ids: [],
      category_ids: []
    )

    if permitted.key?(:tag_names)
      tag_names = permitted.delete(:tag_names).to_s.split(",").map(&:strip).reject(&:blank?)
      permitted[:tag_ids] = tag_names.map { |name| Tag.find_or_create_by_name(name)&.id }.compact
    end

    permitted
  end
end
