class Api::V1::ReviewCommentsController < ApplicationController
  include CommentableActions

  before_action :authenticate_user!, only: [ :create ]

  private

  # Same visibility rule as ReviewLikesController: drafts are only visible to
  # their author and to wine managers, so a draft's thread is 404 for everyone
  # else rather than an empty list.
  def find_commentable
    scope = Review.all
    scope = scope.visible_to(current_user) unless current_user&.wine_manager?
    review = scope.find_by(slug: params[:review_id]) ||
             scope.where(id: params[:review_id]).first
    return review if review

    render_commentable_not_found("Review not found")
    nil
  end
end