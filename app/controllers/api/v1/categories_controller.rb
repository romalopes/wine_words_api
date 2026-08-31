class Api::V1::CategoriesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  SORT_COLUMNS = {
    "wine" => :sort_order_wine,
    "review" => :sort_order_review,
    "article" => :sort_order_article,
  }.freeze

  # Returns categories usable for a given context. Pass:
  #   ?type=wine      -> for_wine categories (used on the wine form)
  #   ?type=article   -> for_article categories
  #   ?type=review    -> for_review categories
  #   ?type=managed   -> all categories (Super User / Editor / Reviewer form use)
  def index
    case params[:type]
    when "wine"
      cats = Category.where(for_wine: true)
    when "article"
      cats = Category.where(for_article: true)
    when "review"
      cats = Category.where(for_review: true)
    else
      cats = Category.all
    end

    render json: cats.order(:name).map do |c|
      { id: c.id, name: c.name, slug: c.slug,
        for_wine: c.for_wine, for_article: c.for_article, for_review: c.for_review,
        sort_order_wine: c.sort_order_wine,
        sort_order_review: c.sort_order_review,
        sort_order_article: c.sort_order_article }
    end
  end

  # Category show: returns the category plus its wines, reviews and articles
  # (used by the React category detail page).
  def show
    category = Category.find(params[:id])

    wines = category.wines.includes(
      wine_taste_parameters: :taste_parameter, vintages: [], producer: [],
      grapes: [], regions: [:country]
    ).order(:name)

    reviews = category.reviews
    reviews = reviews.visible_to(current_user) unless current_user&.wine_manager?
    reviews = reviews.by_recency.includes(:user, vintage: :wine)

    articles =
      if current_user&.wine_manager? || user_signed_in?
        category.articles.visible_to(current_user)
      else
        category.articles.published
      end.recent

    render json: {
      id: category.id,
      name: category.name,
      slug: category.slug,
      for_wine: category.for_wine,
      for_review: category.for_review,
      for_article: category.for_article,
      wines: wines.map { |wine| WineSerializer.new(wine, request.base_url).as_json },
      reviews: reviews.map { |review| ReviewSerializer.new(review, request.base_url).as_json },
      articles: articles.map do |article|
        {
          id: article.id,
          title: article.title,
          status: article.status,
          author: article.user&.name.presence || article.user&.email,
          published_at: article.published_at&.iso8601
        }
      end
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Category not found" }, status: :not_found
  end

  def create
    category = Category.new(category_params)
    if category.save
      render json: category_payload(category), status: :created
    else
      render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    category = Category.find(params[:id])
    if category.update(category_params)
      render json: category_payload(category)
    else
      render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Category not found" }, status: :not_found
  end

  def destroy
    category = Category.find(params[:id])
    category.destroy!
    render json: { ok: true }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Category not found" }, status: :not_found
  end

  # Persists a drag & drop reorder. Body:
  #   { "type": "wine"|"review"|"article", "ordered_ids": [3, 1, 2, ...] }
  # Each move calls this endpoint; sort_order_<type> is rewritten from position.
  def reorder
    type = params[:type].to_s
    column = SORT_COLUMNS[type]
    return render json: { error: "Invalid type" }, status: :bad_request unless column

    ids = Array(params[:ordered_ids])
    Category.transaction do
      ids.each_with_index do |id, index|
        Category.where(id: id).update_all(column => index + 1)
      end
    end
    render json: { ok: true, type: type, ordered_ids: ids }
  rescue ActiveRecord::RecordNotDestroyed => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def category_params
    params.require(:category).permit(:name, :for_wine, :for_review, :for_article)
  end

  def category_payload(category)
    { id: category.id, name: category.name, slug: category.slug,
      for_wine: category.for_wine, for_article: category.for_article, for_review: category.for_review,
      sort_order_wine: category.sort_order_wine,
      sort_order_review: category.sort_order_review,
      sort_order_article: category.sort_order_article }
  end
end
