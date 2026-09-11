# Full-detail serializer used by Api::V1::ArticlesController#show / #create /
# #update / #my_articles. Ships everything the article detail and edit UIs
# render: body, tags, categories, linked producers/vintages/reviews (with the
# per-link status), and image URLs.
class ArticleSerializer
  include ImageAttributes

  def initialize(article, base_url = nil)
    @article = article
    @base_url = base_url
  end

  def as_json
    {
      id: @article.id,
      slug: @article.slug,
      title: @article.title,
      abstract: @article.abstract,
      body: @article.body,
      status: @article.status,
      user_id: @article.user_id,
      author_name: @article.user&.user_name || @article.user&.email || "Unknown",
      published_at: @article.published_at&.iso8601,
      created_at: @article.created_at&.iso8601,
      updated_at: @article.updated_at&.iso8601,
      tags: @article.tags.map(&:name),
      tag_names: @article.tags.map(&:name).join(", "),
      categories: categories,
      category_ids: @article.categories.map(&:id),
      images: image_urls(@article),
      image_ids: image_ids(@article),
      image_details: image_details(@article),
      primary_image: primary_image(@article),
      producers: producers,
      producer_ids: @article.producers.map(&:id),
      vintages: vintages,
      vintage_ids: @article.vintages.map(&:id),
      reviews: reviews,
      review_ids: @article.reviews.map(&:id)
    }
  end

  private

  def categories
    @article.categories.map { |c| { id: c.id, name: c.name, slug: c.slug } }
  end

  def producers
    @article.producers.map { |p| { id: p.id, name: p.name, slug: p.slug } }
  end

  def vintages
    @article.vintages.map do |v|
      wine = v.wine
      {
        id: v.id,
        year: v.year,
        name: [wine&.name, v.year].compact.join(" "),
        wine_name: wine&.name,
        wine_slug: wine&.slug,
        region: wine&.regions&.order(:name)&.first&.name
      }
    end
  end

  # Reviews linked to the article, including the per-link status from the
  # article_reviews join record (used to filter to "published" links).
  def reviews
    link_by_review = @article.article_reviews.index_by(&:review_id)

    @article.reviews.map do |review|
      link = link_by_review[review.id]
      {
        id: review.id,
        slug: review.slug,
        title: review.title,
        score: review.score&.to_f,
        status: review.status,
        comment: review.comment,
        reviewer_name: review.user&.user_name || review.user&.email || "Unknown",
        link_status: link&.status
      }
    end
  end
end