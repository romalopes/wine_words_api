class RegionsController < ActionController::Base
  layout "application"
  include RequireLogin

  before_action :set_region, only: [:show, :edit, :update, :destroy, :link_wine]
  before_action :ensure_manager!, only: [:new, :edit, :create, :update, :destroy]

  def index
    @countries_tree = Region.build_tree
  end

  def show
    @wines = @region.wines.includes(:producer, :regions, :vintages).order(:name)
  end

  # POST /regions/:id/link_wine (wine_id may be a slug or numeric id).
  def link_wine
    unless current_user&.wine_manager?
      return redirect_to @region, alert: "You are not allowed to manage wines."
    end
    wine = Wine.find_by(slug: params[:wine_id]) || Wine.find_by(id: params[:wine_id])
    unless wine
      return redirect_to @region, alert: "Wine not found."
    end

    if wine.regions.include?(@region)
      redirect_to @region, notice: "#{wine.name} is already linked to #{@region.name}."
    else
      wine.regions << @region
      redirect_to @region, notice: "#{wine.name} was added to #{@region.name}."
    end
  end

  def new
    @region = Region.new
    @countries = Country.order(:name)
    @parent_regions = Region.where(parent_id: nil).order(:name)
  end

  def create
    @region = Region.new(region_params)
    @countries = Country.order(:name)
    @parent_regions = Region.where(parent_id: nil).order(:name)
    if @region.save
      redirect_to regions_path, notice: "Region was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @countries = Country.order(:name)
    @parent_regions = Region.where(parent_id: nil).where.not(id: @region.id).order(:name)
  end

  def update
    @countries = Country.order(:name)
    @parent_regions = Region.where(parent_id: nil).where.not(id: @region.id).order(:name)
    if @region.update(region_params)
      redirect_to regions_path, notice: "Region was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @region.destroy
    redirect_to regions_path, notice: "Region was successfully destroyed."
  end

  private

  def ensure_manager!
    return if @current_user&.super_admin? || @current_user&.editor?
    redirect_to regions_path, alert: "Only Super Users and Editors can manage regions."
  end

  def set_region
    @region = Region.includes(:country).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to regions_path, alert: "Region not found."
  end

  def region_params
    params.require(:region).permit(:name, :country_id, :parent_id, :is_state, :is_appellation)
  end
end