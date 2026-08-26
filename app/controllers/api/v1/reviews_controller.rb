class Api::V1::ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_vintage, only: [:create]
  # Nested vintage listing is optional: /api/v1/reviews (no vintage params)
  # must still serve the top-level feed, so only resolve the vintage when the
  # nested route provides one.
  before_action :set_vintage, only: [:index], if: -> { params[:vintage_id].present? }
  before_action :set_review, only: [:show, :update, :destroy]

  def index
    # When nested under a wine/vintage, only that vintage's reviews apply;
    # otherwise fall back to all reviews visible to the user.
    reviews =
      if @vintage
        @vintage.reviews.visible_to(current_user)
      else
        Review.visible_to(current_user)
      end

    render json: reviews.by_recency.includes(:user, vintage: :wine).map do |r|
      ReviewSerializer.new(r, request.base_url).as_json.merge(
        wine_name: r.vintage.wine.name,
        wine_slug: r.vintage.wine.slug,
        vintage_year: r.vintage.year
      )
    end
  end

  def my_reviews
    reviews = Review.where(user: current_user)
                    .by_recency
                    .includes(:user, vintage: :wine)
    render json: reviews.map { |r| ReviewSerializer.new(r, request.base_url).as_json.merge(wine_name: r.vintage.wine.name, wine_slug: r.vintage.wine.slug, vintage_year: r.vintage.year) }
  end

  def show
    if @review.status == "draft" && @review.user_id != current_user.id
      return render json: { error: "Not found" }, status: :not_found
    end
    render json: ReviewSerializer.new(@review, request.base_url).as_json
  end

  def create
    review = @vintage.reviews.new(review_params)
    review.user = current_user

    if review.save
      render json: ReviewSerializer.new(review, request.base_url).as_json, status: :created
    else
      render json: { errors: review.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @review.user_id != current_user.id
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    if @review.update(review_params)
      render json: ReviewSerializer.new(@review, request.base_url).as_json
    else
      render json: { errors: @review.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @review.user_id != current_user.id
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    @review.destroy
    head :no_content
  end

  private

  def set_vintage
    wine = Wine.find_by!(slug: params[:wine_id])
    @vintage = wine.vintages.find(params[:vintage_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Vintage not found" }, status: :not_found
  end

  def set_review
    @review = Review.includes(:user, vintage: :wine).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Review not found" }, status: :not_found
  end

  def review_params
    params.require(:review).permit(:comment, :score, :status, :published_at, :title, images: [])
  end
end