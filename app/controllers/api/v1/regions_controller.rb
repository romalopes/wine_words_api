class Api::V1::RegionsController < ApplicationController
  # Regions are read publicly (used by the wine-form picker).
  # Create/update/destroy is restricted to wine managers.
  before_action :authenticate_user!, except: [:index, :show, :tree]
  before_action :ensure_wine_manager!, only: [:create, :update, :destroy, :link_wine]
  before_action :set_region, only: [:show, :update, :destroy, :link_wine]

  def index
    regions = Region.includes(:country).order(:name)
    render json: regions.map { |r| region_json(r) }
  end

  def tree
    tree_data = Region.build_tree
    render json: tree_data
  end

  def show
    # Load the region with its full hierarchy path and wines
    region = Region.includes(:wines, country: :grapes, parent: :country)
                    .where(id: params[:id])
                    .first
    
    if region
      render json: region_with_path(region)
    else
      render json: { error: "Region not found" }, status: :not_found
    end
  end

  def region_with_path(region)
    path = region.full_path
    {
      id: region.id,
      name: region.name,
      country_id: region.country_id,
      country: region.country ? { 
        id: region.country.id, 
        name: region.country.name, 
        code: region.country.code, 
        flag_emoji: region.country.flag_emoji 
      } : nil,
      parent_id: region.parent_id,
      parent_name: region.parent_id ? region.parent&.name : nil,
      is_state: region.is_state,
      is_appellation: region.is_appellation,
      full_path: path,
      wines: wines_serialized(region)
    }
  end

  def link_wine
    wine = Wine.find_by(slug: params[:wine_id]) || Wine.find_by(id: params[:wine_id])
    unless wine
      return render json: { error: "Wine not found" }, status: :not_found
    end

    wine.regions << @region unless wine.regions.include?(@region)
    render json: region_with_path(@region)
  end

  # POST /api/v1/regions/:id/link_producer — add the producer to this region.
  def link_producer
    return render json: { error: "Forbidden" }, status: :forbidden unless current_user&.wine_manager?

    producer = Producer.find_by(slug: params[:producer_id]) || Producer.find_by(id: params[:producer_id])
    return render json: { error: "Producer not found" }, status: :not_found unless producer

    producer.regions << @region unless producer.regions.include?(@region)
    render json: { id: @region.id, name: @region.name, linked: true }
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

  def wines_serialized(region)
    wines = region.wines.includes(
      wine_taste_parameters: :taste_parameter, vintages: [], producer: [],
      grapes: [], regions: [:country]
    )
    wines.map { |wine| WineSerializer.new(wine, request.base_url).as_json }
  end

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