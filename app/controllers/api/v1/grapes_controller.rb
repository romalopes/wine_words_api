class Api::V1::GrapesController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :ensure_wine_manager!, only: [:create, :update, :destroy]
  before_action :set_grape, only: [:show, :update, :destroy]

  def index
    grapes = Grape.relevance_order
    render json: grapes
  end

  def show
    render json: @grape
  end

  def create
    grape = Grape.new(grape_params)
    if grape.save
      render json: grape, status: :created
    else
      render json: { errors: grape.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @grape.update(grape_params)
      render json: @grape
    else
      render json: { errors: @grape.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @grape.destroy
    head :no_content
  end

  private

  def set_grape
    @grape = Grape.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Grape not found" }, status: :not_found
  end

  def grape_params
    params.require(:grape).permit(
      :name, :color, :origin_country, :is_blending_grape, :serving, :relevance,
      main_regions: [], synonyms: [], notes: []
    )
  end

  def ensure_wine_manager!
    return if current_user&.wine_manager?
    render json: { error: "Forbidden" }, status: :forbidden
  end
end
