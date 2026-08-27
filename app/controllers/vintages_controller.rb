class VintagesController < ActionController::Base
  layout "application"
  helper :vintages
  include RequireLogin

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

  def find_vintage
    Vintage.find_by(id: params[:id]) ||
      Vintage.joins(:wine).find_by!("wines.slug || '-' || CAST(vintages.year AS TEXT) = ?", params[:id])
  end

  def vintage_params
    params.require(:vintage).permit(:year, :prompt, :price, :no_vintage, :wine_id)
  end
end