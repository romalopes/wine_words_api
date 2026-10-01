class Api::V1::WineCommentsController < ApplicationController
  include CommentableActions

  before_action :authenticate_user!, only: [ :create ]

  private

  def find_commentable
    Wine.find_by(slug: params[:wine_id]) || Wine.find(params[:wine_id])
  rescue ActiveRecord::RecordNotFound
    render_commentable_not_found("Wine not found")
    nil
  end
end