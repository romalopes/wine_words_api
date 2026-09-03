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
    render json: country_detail_json(@country)
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

  def country_detail_json(country)
    {
      id: country.id,
      name: country.name,
      code: country.code,
      continent: country.continent,
      flag_emoji: country.flag_emoji,
      is_wine_country: country.is_wine_country,
      producers: country_producers_json(country),
      wines: country_wines_json(country),
    }
  end

  def country_producers_json(country)
    producers = Producer.where(country_id: country.id).order(:name)
    producer_ids = producers.map(&:id)
    wines_count_map = Wine
      .where(producer_id: producer_ids)
      .group(:producer_id)
      .count

    producers.map do |producer|
      {
        id: producer.id,
        slug: producer.slug,
        name: producer.name,
        producer_type: producer.producer_type,
        founded_year: producer.founded_year,
        country: country_json(producer.country),
        wines_count: wines_count_map[producer.id] || 0,
        logo_url: producer_logo_url(producer),
      }
    end
  end

  def country_wines_json(country)
    Wine
      .joins(:producer)
      .where(producers: { country_id: country.id })
      .includes(
        vintages: [],
        wine_taste_parameters: :taste_parameter,
        producer: [],
        grapes: [],
        regions: [:country],
      )
      .order(:name)
      .map { |wine| WineSerializer.new(wine, request.base_url).as_json }
  end

  def country_json(country)
    return nil if country.blank?

    {
      id: country.id,
      name: country.name,
      code: country.code,
      flag_emoji: country.flag_emoji,
    }
  end

  def producer_logo_url(producer)
    return nil unless producer.logo.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      producer.logo,
      host: request.base_url,
    )
  end

  def country_params
    params.require(:country).permit(:name, :code, :continent, :flag_emoji, :is_wine_country)
  end

  def ensure_manager!
    return if current_user&.wine_manager?
    render json: { error: "Forbidden" }, status: :forbidden
  end
end