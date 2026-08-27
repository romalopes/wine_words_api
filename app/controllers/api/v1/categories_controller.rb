class Api::V1::CategoriesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  # Returns categories usable for a given context. Pass:
  #   ?type=wine      -> for_wine categories (used on the wine form)
  #   ?type=article   -> for_article categories
  #   ?type=review    -> for_review categories
  #   ?type=managed   -> all categories (Super User / Editor / Reviewer form use)
  def index
    case params[:type]
    when "wine"
      cats = Category.where(for_wine: true)
    when "article"
      cats = Category.where(for_article: true)
    when "review"
      cats = Category.where(for_review: true)
    else
      cats = Category.all
    end

    render json: cats.order(:name).map do |c|
      { id: c.id, name: c.name, slug: c.slug,
        for_wine: c.for_wine, for_article: c.for_article, for_review: c.for_review,
        sort_order_wine: c.sort_order_wine,
        sort_order_review: c.sort_order_review,
        sort_order_article: c.sort_order_article }
    end
  end
end