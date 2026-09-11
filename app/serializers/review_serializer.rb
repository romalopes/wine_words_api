# Full-detail serializer used by Api::V1::ReviewsController#show / #create /
# #update / #my_reviews. Ships everything the review detail and edit UIs
# render: comment, drink window, wine/vintage context, categories and images.
class ReviewSerializer
  include ImageAttributes

  def initialize(review, base_url = nil)
    @review = review
    @base_url = base_url
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
      reviewer_name: @review.user&.user_name || @review.user&.email || "Unknown",
      vintage_id: @review.vintage_id,
      vintage_year: @review.vintage&.year,
      vintage_no_vintage: @review.vintage&.no_vintage,
      wine_name: @review.vintage&.wine&.name,
      wine_slug: @review.vintage&.wine&.slug,
      category: @review.categories.map(&:name).join(", ").presence,
      categories: categories,
      category_ids: @review.categories.map(&:id),
      images: image_urls(@review),
      image_ids: image_ids(@review),
      image_details: image_details(@review),
      primary_image: primary_image(@review),
      published_at: @review.published_at&.iso8601,
      created_at: @review.created_at&.iso8601,
      updated_at: @review.updated_at&.iso8601
    }
  end

  private

  def categories
    @review.categories.map { |c| { id: c.id, name: c.name, slug: c.slug } }
  end
end
