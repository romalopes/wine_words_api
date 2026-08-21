class VintagesController < ActionController::Base
  layout "application"
  helper :vintages

  def index
    @vintages = Vintage.includes(:wine, :reviews).order(year: :desc)
  end

  def show
    @vintage = Vintage.find(params[:id])
  end

  def new
    @vintage = Vintage.new
  end

  def create
    @vintage = Vintage.new(vintage_params)
    if @vintage.save
      redirect_to @vintage, notice: "Vintage was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @vintage = Vintage.find(params[:id])
  end

  def update
    @vintage = Vintage.find(params[:id])
    if @vintage.update(vintage_params)
      redirect_to @vintage, notice: "Vintage was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @vintage = Vintage.find(params[:id])
    @vintage.destroy
    redirect_to vintages_url, notice: "Vintage was successfully destroyed."
  end

  private

  def vintage_params
    params.require(:vintage).permit(:year, :prompt, :wine_id)
  end
end