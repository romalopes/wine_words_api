class RegionsController < ActionController::Base
  layout "application"
  include RequireLogin

  before_action :set_region, only: [:show, :edit, :update, :destroy]
  before_action :ensure_manager!, only: [:new, :edit, :create, :update, :destroy]

  def index
    @regions = Region.includes(:country).order(:name)
  end

  def show
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