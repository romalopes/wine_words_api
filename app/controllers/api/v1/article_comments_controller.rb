class Api::V1::ArticleCommentsController < ApplicationController
  include CommentableActions

  before_action :authenticate_user!, only: [ :create ]

  private

  # Same visibility rule as the review controller (see ReviewCommentsController).
  def find_commentable
    scope = Article.all
    scope = scope.visible_to(current_user) unless current_user&.wine_manager?
    article = scope.find_by(slug: params[:article_id]) ||
              scope.where(id: params[:article_id]).first
    return article if article

    render_commentable_not_found("Article not found")
    nil
  end
end