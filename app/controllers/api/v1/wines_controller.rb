class Api::V1::WinesController < ApplicationController

  # before_action :authenticate_user!, only: [:create, :update, :destroy]
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    wines = Wine.includes(wine_taste_parameters: :taste_parameter, vintages: [], winery: []).order(:name)
    render json: wines.map { |wine| WineSerializer.new(wine).as_json }
  end

  def show
    wine = Wine.includes(vintages: [], wine_taste_parameters: :taste_parameter, winery: []).find_by!(slug: params[:id])
    render json: WineSerializer.new(wine).as_json
  end

  def create
    @wine = Wine.new(wine_params)
    if @wine.save
      render json: WineSerializer.new(@wine).as_json, status: :created
    else
      render json: { errors: @wine.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @wine = Wine.find_by!(slug: params[:id])
    if @wine.update(wine_params)
      render json: WineSerializer.new(@wine).as_json
    else
      render json: { errors: @wine.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @wine = Wine.find_by!(slug: params[:id])
    @wine.destroy
    head :no_content
  end

  private

  def wine_params
    permitted = params.require(:wine).permit(
      :name, :region, :color, :prompt, :closure, :alcohol_percentage, :volume_ml, :winery_id,
      vintages_attributes: [:id, :year, :prompt, :_destroy],
      # wine_taste_parameters_attributes: [:id, :taste_parameter_slug, :score, :_destroy]
      wine_taste_parameters_attributes: [:id, :taste_parameter_id, :taste_parameter_slug, :score, :_destroy]
    )


    # Convert taste_parameter_slug to taste_parameter_id
    if permitted[:wine_taste_parameters_attributes]
      permitted[:wine_taste_parameters_attributes].each do |attrs|
        if attrs[:taste_parameter_slug].present?
          tp = TasteParameter.find_by(slug: attrs[:taste_parameter_slug])
          attrs[:taste_parameter_id] = tp&.id
          attrs.delete(:taste_parameter_slug)
        end
      end
    end
    permitted
  end
end

