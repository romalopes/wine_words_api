class VintagesController < ActionController::Base
  layout "application"
  helper :vintages
  include RequireLogin

  # Only Super Users, Editors and Reviewers may add/edit/delete vintages.
  before_action :deny_unless_wine_manager!, only: [:new, :create, :edit, :update, :destroy]
  helper_method :can_manage_wines?

  def index
    @vintages = Vintage.includes(:wine, :reviews).order(year: :desc)
  end

  def show
    @vintage = find_vintage
  end

  def new
    @vintage = Vintage.new(wine_id: params[:wine_id])
  end

  def create
    @vintage = Vintage.new(vintage_params)
    if @vintage.save
      redirect_to @vintage.wine, notice: "Vintage was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @vintage = find_vintage
  end

  def update
    @vintage = find_vintage
    if @vintage.update(vintage_params)
      redirect_to @vintage.wine, notice: "Vintage was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @vintage = find_vintage
    wine = @vintage.wine
    @vintage.destroy
    redirect_to wine ? wine_path(wine.slug) : vintages_url, notice: "Vintage was successfully destroyed."
  end

  private

  def can_manage_wines?
    user_signed_in? && current_user.wine_manager?
  end

  def deny_unless_wine_manager!
    return if can_manage_wines?

    redirect_to wines_path, alert: "You are not allowed to manage vintages."
    false
  end

  def find_vintage
    Vintage.find_by(id: params[:id]) ||
      Vintage.joins(:wine).find_by!("wines.slug || '-' || CAST(vintages.year AS TEXT) = ?", params[:id])
  end

  def vintage_params
    params.require(:vintage).permit(:year, :prompt, :price, :no_vintage, :wine_id)
  end
end