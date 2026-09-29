class Api::V1::ArticlesController < ApplicationController
  audit_actions :create, :update, :destroy

  def log_description
    "#{audit_verb} article \"#{@article.title}\""
  end

  def log_objects
    [@article].compact
  end

  before_action :authenticate_user!, except: [:index, :show, :grouped]
  before_action :set_article, only: [:show, :update, :destroy]
  # Only Admins, Editors and Reviewers may create articles.
  before_action :ensure_wine_manager!, only: [:create]

  def index
    # `:categories` (through) and `:images` rather than the join rows alone:
    # the list serializer reads `article.categories`, and a through-association
    # is not satisfied by preloading `article_categories`, so each card used to
    # issue its own queries.
    articles = Article.recent.includes(:user, :categories, :tags, :wines, :producers,
                                      images: { file_attachment: :blob })
    # Content managers see everything (including drafts); everyone else sees
    # only what's visible to them (published + their own drafts).
    articles = articles.visible_to(current_user) unless current_user&.wine_manager?
    articles = articles.joins(:article_categories).where(article_categories: { category_id: params[:category_id] }).distinct if params[:category_id].present?
    articles = articles.left_outer_joins(:article_categories).where(article_categories: { id: nil }) if params[:uncategorised] == "true"
    # Full-text search (title, abstract, body, tags, category, author) plus the
    # requested ordering. `ordered_for_search` replaces `recent` instead of
    # appending to it, otherwise recency wins and relevance is silently ignored.
    term = search_term
    articles = articles.text_search(term)
                       .ordered_for_search(params[:sort], ranked: ranked_search?(term))
    return if render_paginated(articles) { |items| items.map { |a| ArticleListSerializer.new(a, request.base_url).as_json } }

    render json: articles.map { |a| ArticleListSerializer.new(a, request.base_url).as_json }
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
    # Same search scoping as #index, including the `rank` column when the term
    # is searchable — the window function below orders each category's rows by
    # it, so "N most relevant per category" agrees with the paginated feed.
    term = search_term
    ranked = ranked_search?(term)
    scope = scope.text_search(term)
    # Whitelisted fragment qualified with the subquery alias (Article::SORT_ORDERS).
    order_sql = Article.search_order_sql(params[:sort], ranked: ranked, columns: "a.")

    # Cap each category at `per_group` rows with a window function. The outer
    # ORDER BY matters: the window's own ORDER BY only decides *which* rows are
    # numbered 1..N, Postgres does not guarantee any output order without it.
    rows = Article.find_by_sql([<<~SQL, per_group])
      SELECT sub.* FROM (
        SELECT DISTINCT a.id, a.title, a.abstract, a.status,
               a.user_id, a.created_at, a.updated_at,
               COALESCE(ac.category_id, 0) AS grouped_cat_id,
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
                        .includes(:user, :categories, images: { file_attachment: :blob })
                        .index_by(&:id)

    groups = Hash.new { |h, k| h[k] = [] }
    rows.each do |row|
      cat_id = row.grouped_cat_id == 0 ? nil : row.grouped_cat_id
      groups[cat_id] << ArticleListSerializer.new(articles_by_id[row.id], request.base_url).as_json
    end

    # Counts come from the filtered scope too, so "Show all (N)" matches the
    # cards that are actually rendered. `except(:select)` drops the `rank`
    # column search added: it is not aggregated or grouped, so keeping it would
    # make these GROUP BY / COUNT statements invalid.
    count_scope = scope.except(:select)
    category_counts = count_scope.joins(:article_categories).group("article_categories.category_id").count
    uncategorised_count =
      if groups.key?(nil)
        count_scope.left_outer_joins(:article_categories).where(article_categories: { id: nil }).count
      else
        0
      end

    categories = Category.where(id: groups.keys.compact).to_a
    ordered = categories.select { |c| c.sort_order_article.present? }.sort_by { |c| [c.sort_order_article, c.name.to_s] }
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
    articles = Article.where(user: current_user).recent.includes(:user, :category, :tags, :wines, :producers)
    render json: articles.map { |a| ArticleSerializer.new(a, request.base_url).as_json }
  end

  def show
    if @article.status == "draft" &&
       @article.user_id != current_user&.id &&
       !current_user&.wine_manager?
      return render json: { error: "Not found" }, status: :not_found
    end

    render json: ArticleSerializer.new(@article, request.base_url).as_json
  end

  def create
    article = Article.new(article_params)
    article.user = current_user
    if article.save
      image_errors = attach_images(article)
      if image_errors.any?
        return render json: { errors: image_errors }, status: :unprocessable_entity
      end

      render json: ArticleSerializer.new(article, request.base_url).as_json, status: :created
    else
      render json: { errors: article.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    unless @article.user_id == current_user.id || current_user.wine_manager?
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    if @article.update(article_params)
      image_errors = attach_images(@article)
      if image_errors.any?
        return render json: { errors: image_errors }, status: :unprocessable_entity
      end

      render json: ArticleSerializer.new(@article, request.base_url).as_json
    else
      render json: { errors: @article.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    unless @article.user_id == current_user.id || current_user.wine_manager?
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    @article.destroy
    head :no_content
  end

  private

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

  def ensure_wine_manager!
    return if current_user&.wine_manager?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def set_article
    @article = Article.includes(:user, :tags, :producers,
                                 vintages: :wine,
                                 article_reviews: :review,
                                 article_categories: :category)
                       .find_by(slug: params[:id]) || Article.find(params[:id])
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

  def article_params
    permitted = params.require(:article).permit(
      :title, :abstract, :body, :status, :published_at,
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
