class CategoriesController < ActionController::Base
  layout "application"
  include RequireLogin

  before_action :set_current_user, only: [:reorder]
  before_action :require_login, only: [:reorder]
  before_action :set_category, only: [:show, :edit, :update, :destroy]

  def index
    @categories = Category.order(:name)
  end

  def show
    @articles =
      if user_signed_in?
        @category.category_articles.visible_to(current_user).recent
      else
        @category.category_articles.published.recent
      end
    @wines = @category.category_wines.includes(:producer, :regions, :vintages).order(:name)
    @reviews =
      if user_signed_in?
        @category.category_reviews.visible_to(current_user)
      else
        @category.category_reviews.published
      end.by_recency.includes(:user, vintage: :wine)
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)
    if @category.save
      redirect_to categories_path, notice: "Category was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @category.update(category_params)
      redirect_to categories_path, notice: "Category was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Persists drag & drop reordering. Receives:
  #   { "type": "wine"|"review"|"article", "ordered_ids": [3, 1, 2, ...] }
  def reorder
    column = {
      "wine" => :sort_order_wine,
      "review" => :sort_order_review,
      "article" => :sort_order_article,
    }[params[:type].to_s]
    return head :bad_request unless column

    Category.transaction do
      Array(params[:ordered_ids]).each_with_index do |id, index|
        Category.where(id: id).update_all(column => index + 1)
      end
    end
    head :ok
  end

  def destroy
    @category.destroy
    redirect_to categories_path, notice: "Category was successfully destroyed."
  end

  private

  def set_category
    @category = Category.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to categories_path, alert: "Category not found."
  end

  def category_params
    params.require(:category).permit(:name, :for_wine, :for_review, :for_article)
  end
end