# Full-detail serializer used by Api::V1::ReviewsController#show / #create /
# #update / #my_reviews. Ships everything the review detail and edit UIs
# render: comment, drink window, wine/vintage context, categories and images.
class ReviewSerializer
  include ImageAttributes
  include LikeAttributes

  def initialize(review, base_url = nil, liked_ids: nil)
    @review = review
    @base_url = base_url
    @liked_ids = liked_ids
  end

  def as_json
    {
      id: @review.id,
      slug: @review.slug,
      title: @review.title,
      comment: @review.comment,
      score: @review.score&.to_f,
      status: @review.status,
      drink_from: @review.drink_from,
      drink_to: @review.drink_to,
      drink_plus: @review.drink_plus,
      user_id: @review.user_id,
      reviewer_name: @review.user&.display_name || @review.user&.email || "Unknown",
      vintage_id: @review.vintage_id,
      vintage_year: @review.vintage&.year,
      vintage_no_vintage: @review.vintage&.no_vintage,
      wine_name: @review.vintage&.wine&.name,
      wine_slug: @review.vintage&.wine&.slug,
      category: @review.categories.map(&:name).join(", ").presence,
      categories: categories,
      category_ids: @review.categories.map(&:id),
      source: @review.source,
      images: image_urls(@review),
      image_ids: image_ids(@review),
      image_details: image_details(@review),
      primary_image: primary_image(@review) || wine_primary_image,
      # Wine fallback: when the review itself has no images, the UI shows
      # the reviewed wine's image instead (same as the list serializer's
      # `wine_image`, but merged here so `primary_image` just works).
      wine_image: wine_primary_image,
      published_at: @review.published_at&.iso8601,
      created_at: @review.created_at&.iso8601,
      updated_at: @review.updated_at&.iso8601,
      **like_fields(@review, @liked_ids)
    }
  end

  private

  def categories
    @review.categories.map { |c| { id: c.id, name: c.name, slug: c.slug } }
  end

  # Primary image of the reviewed wine (vintage -> wine), or nil.
  # Used as fallback when the review itself carries no images.
  # Falls back further to the wine's own `wine_image`/primary chain so the
  # full-size original is used rather than a cropped variant.
  def wine_primary_image
    wine = @review.vintage&.wine
    return nil unless wine&.images&.any?

    images = ordered_images(wine)
    primary = images.find(&:primary?) || images.first
    primary&.file&.attached? ? blob_url(primary.file.blob) : nil
  end
end
