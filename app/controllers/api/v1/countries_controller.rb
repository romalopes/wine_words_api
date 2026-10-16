class Api::V1::CountriesController < ApplicationController
  audit_actions :create, :update, :destroy

  def log_description
    "#{audit_verb} country \"#{@country.name}\""
  end

  def log_objects
    [@country].compact
  end

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
      .count unless params[:include_wine_counts] == "false"

    render json: countries.map { |country|
      country.as_json(only: %i[id slug name code continent flag_emoji is_wine_country]).merge(
        producers_count: producer_counts[country.id] || 0
      ).merge(wine_counts ? { wines_count: wine_counts[country.id] || 0 } : {})
    }
  end

  def show
    render json: country_detail_json(@country)
  end

  # POST /api/v1/countries/:id/link_producer — assign the producer to this country.
  def link_producer
    return render json: { error: "Forbidden" }, status: :forbidden unless current_user&.wine_manager?

    producer = Producer.find_by(slug: params[:producer_id]) || Producer.find_by(id: params[:producer_id])
    return render json: { error: "Producer not found" }, status: :not_found unless producer

    country = Country.find(params[:id])
    producer.update!(country_id: country.id)
    render json: { id: country.id, name: country.name, linked: true }
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
    @country = Country.find_by(slug: params[:id]) || Country.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Country not found" }, status: :not_found
  end

  def country_detail_json(country)
    # Lean payload: the React CountryDetail page reads only the country's own
    # fields and fetches producers/wines separately via the paginated
    # /api/v1/producers?country_id=... and /api/v1/wines?country_id=... lists.
    # Inlining every producer and wine of the country (full WineSerializer)
    # made show responses for large wine countries grow unbounded.
    {
      id: country.id,
      slug: country.slug,
      name: country.name,
      code: country.code,
      continent: country.continent,
      flag_emoji: country.flag_emoji,
      is_wine_country: country.is_wine_country,
    }
  end

  def country_params
    params.require(:country).permit(:name, :code, :continent, :flag_emoji, :is_wine_country)
  end

  def ensure_manager!
    return if current_user&.wine_manager?
    render json: { error: "Forbidden" }, status: :forbidden
  end
end