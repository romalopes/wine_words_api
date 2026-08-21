class Api::V1::WineriesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    wineries = Winery.includes(:wines).order(:name)
    render json: wineries.map { |winery| winery_json(winery) }
  end

  def show
    winery = Winery.includes(:wines).find_by!(slug: params[:id])
    render json: winery_json(winery)
  end

  def create
    @winery = Winery.new(winery_params)
    if @winery.save
      render json: winery_json(@winery), status: :created
    else
      render json: { errors: @winery.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @winery = Winery.find_by!(slug: params[:id])
    if @winery.update(winery_params)
      render json: winery_json(@winery)
    else
      render json: { errors: @winery.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @winery = Winery.find_by!(slug: params[:id])
    @winery.destroy
    head :no_content
  end

  private

  def winery_params
    params.require(:winery).permit(:name, :address, :email)
  end

  def winery_json(winery)
    {
      id: winery.id,
      slug: winery.slug,
      name: winery.name,
      address: winery.address,
      email: winery.email,
      wines: winery.wines.map do |wine|
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