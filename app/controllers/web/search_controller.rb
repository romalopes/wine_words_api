module Web
  class SearchController < BaseController
    # Global wine search (mirrors React's /search). Renders a search box and
    # a results region driven by the WineSearch Stimulus controller (debounced
    # calls to the same advanced-search logic the API uses).
    def index; end

    # JSON results backing the search-as-you-type box. Matches a wine by its
    # name OR its producer's name (mirroring React's /search).
    def results
      query = params[:query].to_s.strip
      wines =
        if query.blank?
          Wine.none
        else
          Wine.joins(:producer)
              .where("wines.name ILIKE ? OR producers.name ILIKE ?", "%#{query}%", "%#{query}%")
              .distinct
              .includes(:producer, :vintages, :grapes, :regions)
              .order(:name)
              .limit(20)
        end

      render json: wines.map { |wine| wine_result_json(wine) }
    end

    private

    def wine_result_json(wine)
      producer = wine.producer
      {
        slug: wine.slug,
        name: wine.name,
        color: wine.color,
        producer: producer ? producer.name : nil,
        grapes: wine.grapes.map(&:name),
        regions: wine.regions.map(&:name),
        vintage_years: wine.vintages.order(year: :desc).map(&:year),
        score: best_score(wine)
      }
    end

    def best_score(wine)
      wine.vintages
          .joins(:reviews).where(reviews: { status: "published" })
          .maximum("reviews.score")
    end
  end
end
