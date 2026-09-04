class Api::V1::ArticlesController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :set_article, only: [:show, :update, :destroy]
  # Only Super Users, Editors and Reviewers may create articles.
  before_action :ensure_wine_manager!, only: [:create]

  def index
    articles = Article.recent.includes(:user, :category, :tags, :wines, :producers)
    # Content managers see everything (including drafts); everyone else sees
    # only what's visible to them (published + their own drafts).
    articles = articles.visible_to(current_user) unless current_user&.wine_manager?
    articles = articles.joins(:article_categories).where(article_categories: { category_id: params[:category_id] }) if params[:category_id].present?
    articles = articles.left_outer_joins(:article_categories).where(article_categories: { id: nil }) if params[:uncategorised] == "true"
    return if render_paginated(articles) { |items| items.map { |a| ArticleSerializer.new(a, request.base_url).as_json } }

    render json: articles.map { |a| ArticleSerializer.new(a, request.base_url).as_json }
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