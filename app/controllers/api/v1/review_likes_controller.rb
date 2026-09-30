class Api::V1::ReviewLikesController < ApplicationController
  include LikeableActions

  before_action :authenticate_user!, only: [ :create, :destroy ]

  private

  def find_likeable
    scope = Review.all
    scope = scope.visible_to(current_user) unless current_user&.wine_manager?
    review = scope.find_by(slug: params[:review_id]) ||
             scope.where(id: params[:review_id]).first
    return review if review

    render_likeable_not_found("Review not found")
    nil
  end
end
