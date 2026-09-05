class Api::V1::ArticlesController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :set_article, only: [:show, :update, :destroy]
  # Only Super Users, Editors and Reviewers may create articles.
  before_action :ensure_wine_manager!, only: [:create]

  def index
    articles = Article.recent.includes(:user, :tags, :wines, :producers, article_categories: :category)
    # Content managers see everything (including drafts); everyone else sees
    # only what's visible to them (published + their own drafts).
    articles = articles.visible_to(current_user) unless current_user&.wine_manager?
    articles = articles.joins(:article_categories).where(article_categories: { category_id: params[:category_id] }) if params[:category_id].present?
    articles = articles.left_outer_joins(:article_categories).where(article_categories: { id: nil }) if params[:uncategorised] == "true"
    articles = articles.where("articles.title ILIKE ?", "%#{params[:query].strip}%") if params[:query].present?
    return if render_paginated(articles) { |items| items.map { |a| ArticleListSerializer.new(a, request.base_url).as_json } }

    render json: articles.map { |a| ArticleListSerializer.new(a, request.base_url).as_json }
  end

  # GET /api/v1/articles/grouped?per_group=12
  # Server-side "12 articles per category" view for the All Articles page.
  def grouped
    per_group = params[:per_group].to_i
    per_group = 12 if per_group <= 0
    per_group = per_group.clamp(1, 50)

    rows = Article.find_by_sql([<<~SQL, per_group])
      SELECT sub.* FROM (
        SELECT articles.*, COALESCE(ac.category_id, 0) AS grouped_cat_id,
               ROW_NUMBER() OVER (
                 PARTITION BY COALESCE(ac.category_id, 0)
                 ORDER BY articles.created_at DESC
               ) AS rn
        FROM articles
        LEFT JOIN article_categories ac ON ac.article_id = articles.id
        WHERE articles.status = 'published'
      ) sub
      WHERE sub.rn <= ?
    SQL

    article_ids = rows.map(&:id).uniq
    articles_by_id = Article.where(id: article_ids)
                        .includes(:user, article_categories: :category)
                        .index_by(&:id)

    groups = Hash.new { |h, k| h[k] = [] }
    rows.each do |row|
      cat_id = row.grouped_cat_id == 0 ? nil : row.grouped_cat_id
      groups[cat_id] << ArticleListSerializer.new(articles_by_id[row.id], request.base_url).as_json
    end

    category_counts = ArticleCategory.where(category_id: groups.keys.compact).group(:category_id).count
    uncategorised_count =
      if groups.key?(nil)
        Article.left_outer_joins(:article_categories).where(article_categories: { id: nil }).count
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
      attach_images(article)
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
      attach_images(@article)
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

  def ensure_wine_manager!
    return if current_user&.wine_manager?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def set_article
    @article = Article.find_by(slug: params[:id]) || Article.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Article not found" }, status: :not_found
  end

  def attach_images(article)
    return unless params[:article][:images].present?

    article.images.attach(params[:article][:images])
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