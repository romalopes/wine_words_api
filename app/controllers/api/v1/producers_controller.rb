class Api::V1::ProducersController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show, :search]
  # Only Super Users and Reviewers may add, edit or delete producers.
  before_action :ensure_wine_manager!, only: [:create, :update, :destroy]

  def index
    producers = Producer.includes(:wines).order(:name)
    render json: producers.map { |producer| producer_json(producer) }
  end

  # JSON endpoint used by the wine form's "search producers" picker.
  def search
    query = params[:q].to_s.strip
    producers =
      if query.blank?
        Producer.none
      else
        Producer.where("name ILIKE ?", "%#{query}%").order(:name).limit(20)
      end

    render json: producers.map { |producer| producer_search_json(producer) }
  end

  def show
    producer = Producer.includes(:wines).find_by!(slug: params[:id])
    render json: producer_json(producer)
  end

  def create
    @producer = Producer.new(producer_params)
    if @producer.save
      render json: producer_json(@producer), status: :created
    else
      render json: { errors: @producer.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @producer = Producer.find_by!(slug: params[:id])
    if @producer.update(producer_params)
      render json: producer_json(@producer)
    else
      render json: { errors: @producer.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @producer = Producer.find_by!(slug: params[:id])
    @producer.destroy
    head :no_content
  end

  private

  def ensure_wine_manager!
    return if current_user&.wine_manager?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def producer_search_json(producer)
    {
      id: producer.id,
      slug: producer.slug,
      name: producer.name,
      address: producer.address,
      email: producer.email,
      website: producer.website,
      description: producer.description,
      producer_type: producer.producer_type,
      instagram: producer.instagram,
      facebook: producer.facebook
    }
  end

  def producer_params
    params.require(:producer).permit(:name, :address, :email, :website, :description,
                                     :producer_type, :instagram, :facebook, images: [])
  end

  def producer_json(producer)
    {
      id: producer.id,
      slug: producer.slug,
      name: producer.name,
      address: producer.address,
      email: producer.email,
      website: producer.website,
      description: producer.description,
      producer_type: producer.producer_type,
      instagram: producer.instagram,
      facebook: producer.facebook,
      images: image_urls(producer),
      wines: producer.wines.map do |wine|
        {
          id: wine.id,
          slug: wine.slug,
          name: wine.name,
          region: wine.region,
          color: wine.color
        }
      end
    }
  end

    def image_urls(record)
      return [] unless record.images.attached?

      record.images.map do |image|
        Rails.application.routes.url_helpers.rails_blob_url(image, host: request.base_url)
      end
    end
end