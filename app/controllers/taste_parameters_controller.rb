class TasteParametersController < ActionController::Base
  layout "application"
  helper :taste_parameters
  include RequireLogin
  include CatalogueManageable

  before_action :deny_unless_catalogue_manager!, only: [ :new, :create, :edit, :update, :destroy ]

  def index
    @taste_parameters = TasteParameter.includes(:wine_taste_parameters).order(:label)
  end

  def show
    @taste_parameter = TasteParameter.includes(:wine_taste_parameters).find_by!(slug: params[:id])
  end

  def new
    @taste_parameter = TasteParameter.new
  end

  def create
    @taste_parameter = TasteParameter.new(taste_parameter_params)
    if @taste_parameter.save
      redirect_to @taste_parameter, notice: "Taste parameter was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @taste_parameter = TasteParameter.find_by!(slug: params[:id])
  end

  def update
    @taste_parameter = TasteParameter.find_by!(slug: params[:id])
    if @taste_parameter.update(taste_parameter_params)
      redirect_to @taste_parameter, notice: "Taste parameter was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @taste_parameter = TasteParameter.find_by!(slug: params[:id])
    @taste_parameter.destroy
    redirect_to taste_parameters_url, notice: "Taste parameter was successfully destroyed."
  end

  private
    # :slug, :label, :label_1, :label_2, :label_3, :label_4, :label_5, :help
    def taste_parameter_params
      params.require(:taste_parameter).permit(:slug, :label, :label_1, :label_2, :label_3, :label_4, :label_5, :help)
    end
end
