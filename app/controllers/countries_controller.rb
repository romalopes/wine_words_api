class CountriesController < ActionController::Base
  layout "application"
  include RequireLogin

  before_action :set_country, only: [:show, :edit, :update, :destroy]
  before_action :ensure_manager!, only: [:new, :edit, :create, :update, :destroy]

  def index
    @countries = Country.order(:name)
    country_ids = @countries.pluck(:id)

    @producer_counts = Producer
      .where(country_id: country_ids)
      .group(:country_id)
      .count

    @wine_counts = Wine
      .joins(:producer)
      .where(producers: { country_id: country_ids })
      .group("producers.country_id")
      .count
  end

  def show
    # Paginated producers table (20 per page), shared with producers/index.
    per_page = 20
    producer_scope = Producer.where(country_id: @country.id).includes(:wines, :country, :logo_attachment).order(:name)
    producer_count = producer_scope.count
    @producer_count = producer_count
    @producer_total_pages = (producer_count.to_f / per_page).ceil
    @producer_page = (params[:producer_page] || 1).to_i
    @producer_page = 1 if @producer_page < 1 || @producer_page > @producer_total_pages
    @producers = producer_scope
      .limit(per_page)
      .offset((@producer_page - 1) * per_page)

    wine_scope = Wine
      .joins(:producer)
      .where(producers: { country_id: @country.id })
      .includes(:producer, :category, :grapes, :regions, :vintages)
      .order(:name)
    wine_count = wine_scope.count
    @wine_count = wine_count
    @wine_total_pages = (wine_count.to_f / per_page).ceil
    @wine_page = (params[:wine_page] || 1).to_i
    @wine_page = 1 if @wine_page < 1 || @wine_page > @wine_total_pages
    @wines = wine_scope
      .limit(per_page)
      .offset((@wine_page - 1) * per_page)
  end

  def new
    @country = Country.new
  end

  def create
    @country = Country.new(country_params)
    if @country.save
      redirect_to countries_path, notice: "Country was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @country.update(country_params)
      redirect_to countries_path, notice: "Country was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @country.destroy
    redirect_to countries_path, notice: "Country was successfully destroyed."
  end

  private

  def ensure_manager!
    return if @current_user&.super_admin? || @current_user&.editor?
    redirect_to countries_path, alert: "Only Super Users and Editors can manage countries."
  end

  def set_country
    @country = Country.find_by(slug: params[:id]) || Country.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to countries_path, alert: "Country not found."
  end

  def country_params
    params.require(:country).permit(:name, :code, :continent, :flag_emoji, :is_wine_country)
  end
end