class Api::V1::CountriesController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :ensure_manager!, only: [:create, :update, :destroy]
  before_action :set_country, only: [:show, :update, :destroy]

  def index
    countries = Country.order(:name)
    country_ids = countries.pluck(:id)

    producer_counts = Producer
      .where(country_id: country_ids)
      .group(:country_id)
      .count

    wine_counts = Wine
      .joins(:producer)
      .where(producers: { country_id: country_ids })
      .group("producers.country_id")
      .count

    render json: countries.map { |country|
      country.as_json(only: %i[id name code continent flag_emoji is_wine_country]).merge(
        producers_count: producer_counts[country.id] || 0,
        wines_count: wine_counts[country.id] || 0
      )
    }
  end

  def show
    render json: @country
  end

  def create
    country = Country.new(country_params)
    if country.save
      render json: country, status: :created
    else
      render json: { errors: country.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @country.update(country_params)
      render json: @country
    else
      render json: { errors: @country.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @country.destroy
    head :no_content
  end

  private

  def set_country
    @country = Country.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Country not found" }, status: :not_found
  end

  def country_params
    params.require(:country).permit(:name, :code, :continent, :flag_emoji, :is_wine_country)
  end

  def ensure_manager!
    return if current_user&.wine_manager?
    render json: { error: "Forbidden" }, status: :forbidden
  end
end