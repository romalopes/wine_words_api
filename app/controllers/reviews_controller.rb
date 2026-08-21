class ReviewsController < ActionController::Base
  layout "application"
  helper :reviews

  def index
    # @reviews = Review.includes(:vintage).order(created_at: :desc)
    @reviews = Review.order(published_at: :desc)
  end

  def show
    @review = Review.includes(:vintage).find(params[:id])
  end

  def new
    @review = Review.new
  end

  def create
    @review = Review.new(review_params)
    @review.user_id = NeonAuth::User.first.id if NeonAuth::User.first
    puts "\n\n@review: #{@review.inspect}\n\n"
    if @review.save
      redirect_to @review, notice: "Review was successfully created."
    else
      puts "\n\n@review.errors.full_messages: #{@review.errors.full_messages}\n\n"
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @review = Review.find(params[:id])
  end

  def update
    @review = Review.find(params[:id])
    if @review.update(review_params)
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

  private
    # :comment, :score, :vintage_id, :status, :published_at
    def review_params
      params.require(:review).permit(:comment, :score, :vintage_id, :status, :published_at)
    end
end