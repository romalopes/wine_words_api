# Full-detail serializer used by Api::V1::ArticlesController#show / #create /
# #update / #my_articles. Ships everything the article detail and edit UIs
# render: body, tags, categories, linked producers/vintages/reviews (with the
# per-link status), and image URLs.
class ArticleSerializer
  include ImageAttributes
  include LikeAttributes

  def initialize(article, base_url = nil, liked_ids: nil, review_liked_ids: Set.new)
    @article = article
    @base_url = base_url
    @liked_ids = liked_ids
    # `Likes.liked_ids_for` returns one type's ids, so the reviews' own set is
    # passed separately from the article's rather than merged into one set.
    @review_liked_ids = review_liked_ids
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
      author_name: @article.user&.display_name || @article.user&.email || "Unknown",
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
      review_ids: @article.reviews.map(&:id),
      **like_fields(@article, @liked_ids)
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
  #
  # Each entry mirrors `ReviewSerializer` (wine/vintage context, drink window,
  # images and like fields) so the article page can render the shared review
  # card instead of a bespoke stub list.
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
        reviewer_name: review.user&.display_name || review.user&.email || "Unknown",
        link_status: link&.status,
        user_id: review.user_id,
        drink_from: review.drink_from,
        drink_to: review.drink_to,
        drink_plus: review.drink_plus,
        vintage_id: review.vintage_id,
        vintage_year: review.vintage&.year,
        wine_name: review.vintage&.wine&.name,
        wine_slug: review.vintage&.wine&.slug,
        images: image_urls(review),
        primary_image: primary_image(review),
        **like_fields(review, @review_liked_ids)
      }
    end
  end
end
