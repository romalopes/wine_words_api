class Api::V1::VintagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_wine, only: [:create]
  # Only Super Users, Editors and Reviewers may add vintages.
  before_action :ensure_wine_manager!, only: [:create]

  # POST /api/v1/wines/:wine_id/vintages
  def create
    vintage = @wine.vintages.new(vintage_params)

    if vintage.save
      render json: { id: vintage.id, year: vintage.year, prompt: vintage.prompt,
                     price: vintage.price&.to_f, no_vintage: vintage.no_vintage },
             status: :created
    else
      render json: { errors: vintage.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def ensure_wine_manager!
    return if current_user&.wine_manager?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def set_wine
    @wine = Wine.find_by!(slug: params[:wine_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Wine not found" }, status: :not_found
  end

  def vintage_params
    params.require(:vintage).permit(:year, :prompt, :price, :no_vintage)
  end
end