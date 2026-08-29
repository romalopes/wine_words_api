class Api::V1::WinesController < ApplicationController

  # Wine management (create/update/destroy) is restricted to signed-in
  # Super Users and Reviewers; reading stays public.
  before_action :authenticate_user!, only: [:create, :update, :destroy]
  before_action :ensure_wine_manager!, only: [:create, :update, :destroy]
  skip_before_action :authenticate_user!, only: [:index, :show, :search]

  def index
    wines = Wine.includes(wine_taste_parameters: :taste_parameter, vintages: [], producer: [], grapes: []).order(:name)
    render json: wines.map { |wine| WineSerializer.new(wine, request.base_url).as_json }
  end

  def show
    wine = Wine.includes(vintages: [], wine_taste_parameters: :taste_parameter, producer: [], grapes: []).find_by!(slug: params[:id])
    render json: WineSerializer.new(wine, request.base_url).as_json
  end

  def create
    @wine = Wine.new(wine_params)
    if @wine.save
      render json: WineSerializer.new(@wine).as_json, status: :created
    else
      render json: { errors: @wine.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @wine = Wine.find_by!(slug: params[:id])
    if @wine.update(wine_params)
      render json: WineSerializer.new(@wine).as_json
    else
      render json: { errors: @wine.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @wine = Wine.find_by!(slug: params[:id])
    @wine.destroy
    head :no_content
  end

  # JSON endpoint used by the article form's "search wines" picker.
  def search
    query = params[:q].to_s.strip
    wines =
      if query.blank?
        Wine.none
      else
        Wine.where("name ILIKE ?", "%#{query}%").includes(:vintages).order(:name).limit(20)
      end

    render json: wines.map { |wine| wine_search_json(wine) }
  end

  private

  def ensure_wine_manager!
    return if current_user&.wine_manager?

    render json: { error: "Forbidden" }, status: :forbidden
  end

    def wine_search_json(wine)
    {
      id: wine.id,
      name: wine.name,
      slug: wine.slug,
      region: wine.region,
      color: wine.color,
      producer: wine.producer ? { id: wine.producer.id, slug: wine.producer.slug, name: wine.producer.name } : nil,
      category: wine.category&.name,
      vintages: wine.vintages.order(year: :desc).map do |vintage|
        { id: vintage.id, year: vintage.year }
      end
    }
  end

  private

  def wine_params
    permitted = params.require(:wine).permit(
      :name, :region, :color, :sparkling, :prompt, :closure, :alcohol_percentage, :volume_ml, :producer_id, :category_id,
      images: [],
      grape_ids: [],
      vintages_attributes: [:id, :year, :prompt, :price, :no_vintage, :_destroy],
      wine_taste_parameters_attributes: [:id, :taste_parameter_id, :taste_parameter_slug, :score, :_destroy]
    )


    # Convert taste_parameter_slug to taste_parameter_id
    if permitted[:wine_taste_parameters_attributes]
      permitted[:wine_taste_parameters_attributes].each do |attrs|
        if attrs[:taste_parameter_slug].present?
          tp = TasteParameter.find_by(slug: attrs[:taste_parameter_slug])
          attrs[:taste_parameter_id] = tp&.id
          attrs.delete(:taste_parameter_slug)
        end
      end
    end
    permitted
  end
end

