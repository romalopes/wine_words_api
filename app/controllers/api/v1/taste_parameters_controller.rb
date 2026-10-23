class Api::V1::TasteParametersController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  def index
    # render json: TasteParameter.all
    taste_parameters = TasteParameter.all #.includes(wine_profile_taste_parameters: :taste_parameter)
    render json: taste_parameters.map { |taste_parameter| TasteParameterSerializer.new(taste_parameter).as_json }

  end

  def show
    taste_parameter = TasteParameter.find_by!(slug: params[:id])
    render json: TasteParameterSerializer.new(taste_parameter).as_json
  end

  def create
    @taste_parameter = TasteParameter.new(taste_parameter_params)
    if @taste_parameter.save
      render json: @taste_parameter, status: :created
    else
      render json: @taste_parameter.errors, status: :unprocessable_entity
    end
  end

  def update
    @taste_parameter = TasteParameter.find_by!(slug: params[:id])
    if @taste_parameter.update(taste_parameter_params)
      render json: @taste_parameter
    else
      render json: @taste_parameter.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @taste_parameter = TasteParameter.find_by!(slug: params[:id])
    @taste_parameter.destroy
    head :no_content
  end

  private

  def taste_parameter_params
      params.require(:taste_parameter).permit(:id, :slug, :label, :label_1, :label_2, :label_3, :label_4, :label_5, :help)
  end
end