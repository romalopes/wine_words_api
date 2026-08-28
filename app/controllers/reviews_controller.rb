class ReviewsController < ActionController::Base
  layout "application"
  helper :reviews
  include RequireLogin

  helper_method :can_manage_review?
  # Only Super Users, Editors and Reviewers may create reviews.
  before_action :deny_unless_wine_manager!, only: [:new, :create]
  helper_method :can_manage_wines?

  def index
    @scope = can_manage_wines? && params[:scope] == "mine" && user_signed_in? ? "mine" : "all"
    @status = can_manage_wines? && %w[all draft published].include?(params[:status]) ? params[:status] : "all"

    base =
      if @scope == "mine"
        current_user.reviews
      elsif user_signed_in?
        Review.visible_to(current_user)
      else
        Review.published
      end
    base = base.where(status: @status) unless @status == "all"
    @reviews = base.order(published_at: :desc)
    if params[:category].present?
      @reviews = @reviews.joins(:category).where(categories: { name: params[:category] })
    end
  end

  def show
    @review = Review.includes(:vintage).find(params[:id])
    if @review.status == "draft" && (!user_signed_in? || @review.user_id != current_user.id)
      redirect_to reviews_path, alert: "Review not found."
    end
  end

  def new
    @review = Review.new
  end

  def create
    @review = Review.new(review_params)
    @review.user = @current_user
    if @review.save
      attach_images
      redirect_to @review, notice: "Review was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @review = Review.find(params[:id])
    return unless deny_unless_review_manager!(@review)
  end

  def update
    @review = Review.find(params[:id])
    return unless deny_unless_review_manager!(@review)

    if @review.update(review_params)
      attach_images
      redirect_to @review, notice: "Review was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @review = Review.find(params[:id])
    return unless deny_unless_review_manager!(@review)

    @review.destroy
    redirect_to reviews_url, notice: "Review was successfully destroyed."
  end

  def purge_image
    @review = Review.find(params[:id])
    return redirect_to reviews_url, alert: "Not allowed." unless @review.user_id == current_user&.id

    attachment = @review.images.find_by(id: params[:image_id])
    attachment&.purge
    redirect_to edit_review_path(@review), notice: "Image removed."
  end

  private

  def can_manage_wines?
    user_signed_in? && current_user.wine_manager?
  end

  def deny_unless_wine_manager!
    return if can_manage_wines?

    redirect_to reviews_path, alert: "You are not allowed to manage content."
    false
  end

  # Author or super admin may manage a review.
  def can_manage_review?(review)
    user_signed_in? &&
      (review.user_id == current_user.id || current_user.super_admin?)
  end

  def deny_unless_review_manager!(review)
    return true if can_manage_review?(review)

    redirect_to reviews_path, alert: "Not allowed."
    false
  end

  def attach_images
    images = params[:review][:images]
    @review.images.attach(images) if images.is_a?(Array)
  end

    # :comment, :score, :vintage_id, :status, :published_at
    def review_params
      params.require(:review).permit(:title, :comment, :score, :vintage_id, :status, :published_at,
                                     :category_id, :drink_from, :drink_to, :drink_plus)
    end
end