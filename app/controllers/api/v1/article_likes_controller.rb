class Api::V1::ArticleLikesController < ApplicationController
  include LikeableActions

  before_action :authenticate_user!, only: [ :create, :destroy ]

  private

  def find_likeable
    scope = Article.all
    scope = scope.visible_to(current_user) unless current_user&.wine_manager?
    article = scope.find_by(slug: params[:article_id]) ||
              scope.where(id: params[:article_id]).first
    return article if article

    render_likeable_not_found("Article not found")
    nil
  end
end
