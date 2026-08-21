class WineTasteParametersController < ActionController::Base
  layout "application"
  helper :wine_taste_parameters

  def index
    @wine_taste_parameters = WineTasteParameter.includes(:wine, :taste_parameter).order(:score)
  end

  def show
    @wine_taste_parameter = WineTasteParameter.includes(:wine, :taste_parameter).find(params[:id])
  end

  def new
    @wine_taste_parameter = WineTasteParameter.new
  end

  def create
    @wine_taste_parameter = WineTasteParameter.new(wine_taste_parameter_params)
    if @wine_taste_parameter.save
      redirect_to @wine_taste_parameter, notice: "Wine taste parameter was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @wine_taste_parameter = WineTasteParameter.find(params[:id])
  end

  def update
    @wine_taste_parameter = WineTasteParameter.find(params[:id])
    if @wine_taste_parameter.update(wine_taste_parameter_params)
      redirect_to @wine_taste_parameter, notice: "Wine taste parameter was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @wine_taste_parameter = WineTasteParameter.find(params[:id])
    @wine_taste_parameter.destroy
    redirect_to wine_taste_parameters_url, notice: "Wine taste parameter was successfully destroyed."
  end

  private
    # :wine_id, :taste_parameter_id, :score
    def wine_taste_parameter_params
      params.require(:wine_taste_parameter).permit(:wine_id, :taste_parameter_id, :score)
    end
end