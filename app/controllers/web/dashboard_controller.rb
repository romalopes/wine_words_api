class Web::DashboardController < Web::BaseController
  def index
    @producer_count = Producer.count
    @wine_count = Wine.count
    @review_count = Review.published.count

    @article_count =
      if user_signed_in?
        Article.visible_to(current_user).count
      else
        Article.published.count
      end
    @recent_articles = Article.published.recent.limit(3).includes(:user, :category)
    @recent_reviews = Review.published.order(published_at: :desc).limit(3).includes(:user, :vintage)
  end
end