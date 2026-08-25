class ReviewsController < ActionController::Base
  layout "application"
  helper :reviews
  include RequireLogin

  def index
    @reviews =
      if user_signed_in?
        Review.visible_to(current_user).order(published_at: :desc)
      else
        Review.published.order(published_at: :desc)
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
  end

  def update
    @review = Review.find(params[:id])
    if @review.update(review_params)
      attach_images
      redirect_to @review, notice: "Review was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @review = Review.find(params[:id])
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

  def attach_images
    images = params[:review][:images]
    @review.images.attach(images) if images.is_a?(Array)
  end

    # :comment, :score, :vintage_id, :status, :published_at
    def review_params
      params.require(:review).permit(:title, :comment, :score, :vintage_id, :status, :published_at)
    end
end