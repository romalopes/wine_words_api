class CategoriesController < ActionController::Base
  layout "application"
  include RequireLogin

  before_action :set_category, only: [:show, :edit, :update, :destroy]

  def index
    @categories = Category.order(:name)
  end

  def show
    @articles =
      if user_signed_in?
        @category.articles.visible_to(current_user).recent
      else
        @category.articles.published.recent
      end
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
    params.require(:category).permit(:name)
  end
end