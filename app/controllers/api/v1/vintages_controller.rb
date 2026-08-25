class Api::V1::VintagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_wine, only: [:create]

  # POST /api/v1/wines/:wine_id/vintages
  def create
    vintage = @wine.vintages.new(vintage_params)

    if vintage.save
      render json: { id: vintage.id, year: vintage.year, prompt: vintage.prompt },
             status: :created
    else
      render json: { errors: vintage.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_wine
    @wine = Wine.find_by!(slug: params[:wine_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Wine not found" }, status: :not_found
  end

  def vintage_params
    params.require(:vintage).permit(:year, :prompt)
  end
end