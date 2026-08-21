class Api::V1::ProducersController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    producers = Producer.includes(:wines).order(:name)
    render json: producers.map { |producer| producer_json(producer) }
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

  def producer_params
    params.require(:producer).permit(:name, :address, :email)
  end

  def producer_json(producer)
    {
      id: producer.id,
      slug: producer.slug,
      name: producer.name,
      address: producer.address,
      email: producer.email,
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
end