class Api::V1::ReviewsController < ApplicationController
  # Only Super Users, Editors and Reviewers may create reviews.
  before_action :authenticate_user!, except: [:index, :show]
  before_action :ensure_wine_manager!, only: [:create]
  # Resolve @vintage for nested routes. Required for #create; optional for
  # #index (top-level feed runs without vintage params).
  # NOTE: declared ONCE — duplicate before_action declarations of the same
  # filter get merged by Rails and the last `only:`/`if:` silently wins.
  before_action :set_vintage,
                only: [:create, :index],
                if: -> { action_name == "create" || params[:vintage_id].present? }
  before_action :set_review, only: [:show, :update, :destroy]

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
    reviews = reviews.visible_to(current_user) unless current_user&.wine_manager?
    reviews = reviews.by_recency.includes(:user, vintage: :wine, review_categories: :category)
    reviews = reviews.joins(:review_categories).where(review_categories: { category_id: params[:category_id] }) if params[:category_id].present?
    reviews = reviews.left_outer_joins(:review_categories).where(review_categories: { id: nil }) if params[:uncategorised] == "true"
    if params[:query].present?
      q = "%#{params[:query].strip}%"
      reviews = reviews.joins(vintage: :wine).where("reviews.title ILIKE :q OR wines.name ILIKE :q", q: q)
    end

    return if render_paginated(reviews) { |items| serialize_reviews(items) }

    render json: serialize_reviews(reviews)
  end

  # GET /api/v1/reviews/grouped?per_group=12
  # Server-side "12 reviews per category" view for the All Reviews page.
  def grouped
    per_group = params[:per_group].to_i
    per_group = 12 if per_group <= 0
    per_group = per_group.clamp(1, 50)

    rows = Review.find_by_sql([<<~SQL, per_group])
      SELECT sub.* FROM (
        SELECT reviews.*, COALESCE(rc.category_id, 0) AS grouped_cat_id,
               ROW_NUMBER() OVER (
                 PARTITION BY COALESCE(rc.category_id, 0)
                 ORDER BY reviews.created_at DESC
               ) AS rn
        FROM reviews
        LEFT JOIN review_categories rc ON rc.review_id = reviews.id
        WHERE reviews.status = 'published'
      ) sub
      WHERE sub.rn <= ?
    SQL

    review_ids = rows.map(&:id).uniq
    reviews_by_id = Review.where(id: review_ids)
                      .includes(:user, vintage: :wine, review_categories: :category)
                      .index_by(&:id)

    groups = Hash.new { |h, k| h[k] = [] }
    rows.each do |row|
      cat_id = row.grouped_cat_id == 0 ? nil : row.grouped_cat_id
      groups[cat_id] << ReviewListSerializer.new(reviews_by_id[row.id], request.base_url).as_json
    end

    category_counts = ReviewCategory.where(category_id: groups.keys.compact).group(:category_id).count
    uncategorised_count =
      if groups.key?(nil)
        Review.left_outer_joins(:review_categories).where(review_categories: { id: nil }).count
      else
        0
      end

    categories = Category.where(id: groups.keys.compact).to_a
    ordered = categories.select { |c| c.sort_order_review.present? }.sort_by { |c| [c.sort_order_review, c.name.to_s] }
    unordered = categories.reject { |c| c.sort_order_review.present? }.sort_by { |c| c.name.to_s }

    result = (ordered + unordered).map do |cat|
      { category: cat.name, count: category_counts[cat.id] || groups[cat.id].size, reviews: groups[cat.id] }
    end

    if groups.key?(nil)
      result << { category: "Uncategorised", count: uncategorised_count, reviews: groups[nil] }
    end

    render json: result
  end

  def serialize_reviews(reviews)
    reviews.map { |r| ReviewListSerializer.new(r, request.base_url).as_json }
  end

  def my_reviews
    reviews = Review.where(user: current_user)
                    .by_recency
                    .includes(:user, vintage: :wine)
    render json: reviews.map { |r| ReviewSerializer.new(r, request.base_url).as_json.merge(wine_name: r.vintage.wine.name, wine_slug: r.vintage.wine.slug, vintage_year: r.vintage.year) }
  end

  def show
    if @review.status == "draft" &&
       @review.user_id != current_user&.id &&
       !current_user&.wine_manager?
      return render json: { error: "Not found" }, status: :not_found
    end
    render json: ReviewSerializer.new(@review, request.base_url).as_json
  end

  def create
    review = @vintage.reviews.new(review_params)
    review.user = current_user

    if review.title.blank?
      year = @vintage.no_vintage? ? "NV" : @vintage.year
      review.title = "#{@vintage.wine.name} #{year}"
    end

    if review.save
      render json: ReviewSerializer.new(review, request.base_url).as_json, status: :created
    else
      render json: { errors: review.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    unless @review.user_id == current_user.id || current_user.wine_manager?
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    if @review.update(review_params)
      render json: ReviewSerializer.new(@review, request.base_url).as_json
    else
      render json: { errors: @review.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    unless @review.user_id == current_user.id || current_user.wine_manager?
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    @review.destroy
    head :no_content
  end

  private

  def ensure_wine_manager!
    return if current_user&.wine_manager?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def set_vintage
    wine = Wine.find_by!(slug: params[:wine_id])
    @vintage = wine.vintages.find(params[:vintage_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Vintage not found" }, status: :not_found
  end

  def set_review
    @review = Review.includes(:user, vintage: :wine)
                    .find_by(slug: params[:id]) ||
              Review.includes(:user, vintage: :wine).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Review not found" }, status: :not_found
  end

  def review_params
    params.require(:review).permit(:comment, :score, :status, :published_at, :title,
                                   :vintage_id,
                                   :drink_from, :drink_to, :drink_plus, images: [],
                                   category_ids: [])
  end
end