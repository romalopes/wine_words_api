class Api::V1::StatsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    render json: {
      producers: Producer.count,
      wines: Wine.count,
      reviews: Review.published.count,
      articles: current_user ? Article.visible_to(current_user).count : Article.published.count
    }
  end
end
