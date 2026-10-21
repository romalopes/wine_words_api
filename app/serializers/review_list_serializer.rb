# Lean serializer used by Api::V1::ReviewsController#index (list views) only.
# Ships the fields the list/table cards render, avoiding full-detail-only
# payload such as per-image details and the drink window.
class ReviewListSerializer
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
      comment: @review.comment&.slice(0, 50),
      score: @review.score&.to_f,
      status: @review.status,
      reviewer_name: @review.user&.display_name || @review.user&.email || "Unknown",
      wine_name: @review.vintage&.wine&.name,
      wine_slug: @review.vintage&.wine&.slug,
      vintage_year: @review.vintage&.year,
      vintage_no_vintage: @review.vintage&.no_vintage,
      category: @review.categories.map(&:name).join(", ").presence,
      categories: @review.categories.map { |c| { id: c.id, name: c.name, slug: c.slug } },
      published_at: @review.published_at&.iso8601,
      deadline: @review.deadline&.iso8601,
      overdue: @review.overdue?,
      days_until_deadline: @review.days_until_deadline,
      created_at: @review.created_at&.iso8601,
      updated_at: @review.updated_at&.iso8601,
      **like_fields(@review, @liked_ids),
      images: image_urls(@review),
      wine_image: wine_image_url
    }
  end

  private

  def wine_image_url
    wine = @review.vintage&.wine
    return nil unless wine&.images&.any?

    images = ordered_images(wine)
    primary = images.find(&:primary?) || images.first
    primary&.file&.attached? ? blob_url(primary.file.blob) : nil
  end
end