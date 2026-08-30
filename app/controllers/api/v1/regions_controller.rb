class Api::V1::RegionsController < ApplicationController
  # Regions are read publicly (used by the wine-form picker).
  # Create/update/destroy is restricted to wine managers.
  before_action :authenticate_user!, except: [:index, :show]
  before_action :ensure_wine_manager!, only: [:create, :update, :destroy]
  before_action :set_region, only: [:show, :update, :destroy]

  def index
    regions = Region.includes(:country).order(:name)
    render json: regions.map { |r| region_json(r) }
  end

  def show
    render json: region_json(@region)
  end

  def create
    region = Region.new(region_params)
    if region.save
      render json: region_json(region), status: :created
    else
      render json: { errors: region.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @region.update(region_params)
      render json: region_json(@region)
    else
      render json: { errors: @region.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @region.destroy
    head :no_content
  end

  private

  def set_region
    @region = Region.includes(:country).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Region not found" }, status: :not_found
  end

  def region_json(region)
    {
      id: region.id,
      name: region.name,
      country_id: region.country_id,
      country: region.country ? { id: region.country.id, name: region.country.name, code: region.country.code, flag_emoji: region.country.flag_emoji } : nil,
      parent_id: region.parent_id,
      parent_name: region.parent_id ? region.parent&.name : nil,
      is_state: region.is_state,
      is_appellation: region.is_appellation,
    }
  end

  def region_params
    params.require(:region).permit(:name, :country_id, :parent_id, :is_state, :is_appellation)
  end

  def ensure_wine_manager!
    return if current_user&.wine_manager?

    render json: { error: "Forbidden" }, status: :forbidden
  end
end