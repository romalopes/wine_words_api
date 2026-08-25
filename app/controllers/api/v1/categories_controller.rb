class Api::V1::CategoriesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    render json: Category.order(:name).as_json(only: [:id, :name])
  end
end