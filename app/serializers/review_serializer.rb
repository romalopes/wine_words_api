# Lean serializer used by Api::V1::ReviewsController#index (list views) only.
# Ships only the fields the list/table UIs render, avoiding the full detail
# payload (images, comment, drink window, etc.) that dominates response size.
class ReviewListSerializer
  def initialize(review, base_url = nil)
    @review = review
    @base_url = base_url
  end

  def as_json
    {
      id: @review.id,
      slug: @review.slug,
      title: @review.title,
      score: @review.score&.to_f,
      status: @review.status,
      reviewer_name: @review.user&.name || @review.user&.email || "Unknown",
      wine_name: @review.vintage&.wine&.name,
      wine_slug: @review.vintage&.wine&.slug,
      vintage_year: @review.vintage&.year,
      vintage_no_vintage: @review.vintage&.no_vintage,
      category: @review.categories.map(&:name).join(", ").presence,
      categories: @review.categories.map { |c| { id: c.id, name: c.name, slug: c.slug } },
      published_at: @review.published_at&.iso8601,
      created_at: @review.created_at&.iso8601
    }
  end
end
