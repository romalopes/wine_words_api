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
    @producers = Producer.where(country_id: @country.id).order(:name)
    @wines = Wine
      .joins(:producer)
      .where(producers: { country_id: @country.id })
      .includes(:producer, :category, :grapes, :regions, :vintages)
      .order(:name)
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
    @country = Country.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to countries_path, alert: "Country not found."
  end

  def country_params
    params.require(:country).permit(:name, :code, :continent, :flag_emoji, :is_wine_country)
  end
end