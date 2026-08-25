class TagsController < ActionController::Base
  layout "application"
  include RequireLogin

  before_action :set_tag, only: [:show, :edit, :update, :destroy]

  def index
    @tags = Tag.order(:name)
  end

  def show
    @articles =
      if user_signed_in?
        @tag.articles.visible_to(current_user).recent
      else
        @tag.articles.published.recent
      end
  end

  def new
    @tag = Tag.new
  end

  def create
    @tag = Tag.new(tag_params)
    if @tag.save
      redirect_to tags_path, notice: "Tag was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @tag.update(name: tag_params[:name])
      redirect_to tags_path, notice: "Tag was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tag.destroy
    redirect_to tags_path, notice: "Tag was successfully destroyed."
  end

  private

  def set_tag
    @tag = Tag.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to tags_path, alert: "Tag not found."
  end

  def tag_params
    params.require(:tag).permit(:name)
  end
end