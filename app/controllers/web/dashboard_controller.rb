module Web
  class DashboardController < BaseController
    def index
      @producer_count = Producer.count
      @wine_count = Wine.count
      @review_count = Review.count
    end
  end
end