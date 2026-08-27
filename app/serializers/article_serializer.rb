class ArticleSerializer
  def initialize(article, base_url = nil)
    @article = article
    @base_url = base_url
  end

  def as_json
    {
      id: @article.id,
      title: @article.title,
      abstract: @article.abstract,
      body: @article.body,
      status: @article.status,
      author_name: @article.user&.name || @article.user&.email || "Unknown",
      user_id: @article.user_id,
                  category: @article.category&.name,
      category_id: @article.category_id,
      tags: @article.tags.map(&:name),
      wines: wine_list,
      vintages: vintage_list,
      producers: producer_list,
      reviews: review_list,
      images: image_urls,
      image_ids: @article.images.attached? ? @article.images.map(&:id) : [],
      published_at: @article.published_at&.iso8601,
      created_at: @article.created_at&.iso8601
    }
  end

  private

  def wine_list
    @article.wines.map do |wine|
      { id: wine.id, name: wine.name, slug: wine.slug, region: wine.region, color: wine.color }
    end
  end

  def vintage_list
    @article.article_vintages.includes(vintage: :wine).map do |link|
      next unless link.vintage

      vintage = link.vintage
      {
        id: vintage.id,
        year: vintage.year,
        name: "#{vintage.wine&.name} #{vintage.year}",
        wine_id: vintage.wine_id,
        wine_name: vintage.wine&.name,
        wine_slug: vintage.wine&.slug,
        region: vintage.wine&.region,
        color: vintage.wine&.color
      }.compact
    end.compact
  end

  def producer_list
    @article.producers.map do |producer|
      { id: producer.id, name: producer.name, slug: producer.slug }
    end
  end

  def review_list
    @article.article_reviews.includes(review: [:user]).map do |link|
      next unless link.review

      {
        id: link.review.id,
        link_status: link.status,
        title: link.review.title,
        score: link.review.score&.to_f,
        status: link.review.status,
        reviewer_name: link.review.user&.name || link.review.user&.email || "Unknown",
        comment: link.review.comment
      }.compact
    end.compact
  end

  def image_urls
    return [] unless @article.images.attached?

    @article.images.map do |image|
      Rails.application.routes.url_helpers.rails_blob_url(image, host: @base_url || "localhost:3000")
    end
  end
end