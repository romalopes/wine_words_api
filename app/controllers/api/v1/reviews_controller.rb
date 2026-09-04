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
    reviews = reviews.by_recency.includes(:user, vintage: :wine)
    reviews = reviews.joins(:review_categories).where(review_categories: { category_id: params[:category_id] }) if params[:category_id].present?
    reviews = reviews.left_outer_joins(:review_categories).where(review_categories: { id: nil }) if params[:uncategorised] == "true"

    return if render_paginated(reviews) { |items| serialize_reviews(items) }

    render json: serialize_reviews(reviews)
  end

  def serialize_reviews(reviews)
    reviews.map { |r|
      ReviewSerializer.new(r, request.base_url).as_json.merge(
        wine_name: r.vintage.wine.name,
        wine_slug: r.vintage.wine.slug,
        vintage_year: r.vintage.year
      )
    }
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
      review.title = "Review of #{@vintage.wine.name} - #{year}"
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
                                   :drink_from, :drink_to, :drink_plus, images: [],
                                   category_ids: [])
  end
end