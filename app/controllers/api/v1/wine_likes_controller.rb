class Api::V1::WineLikesController < ApplicationController
  include LikeableActions

  before_action :authenticate_user!, only: [ :create, :destroy ]

  private

  def find_likeable
    Wine.find_by(slug: params[:wine_id]) || Wine.find(params[:wine_id])
  rescue ActiveRecord::RecordNotFound
    render_likeable_not_found("Wine not found")
    nil
  end
end
