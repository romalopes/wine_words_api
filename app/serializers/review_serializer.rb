class ReviewSerializer
  def initialize(review, base_url = nil)
    @review = review
    @base_url = base_url
  end

  def as_json
    {
      id: @review.id,
      vintage_id: @review.vintage_id,
      user_id: @review.user_id,
      reviewer_name: @review.user&.name || @review.user&.email || "Unknown",
      title: @review.title,
      comment: @review.comment,
      score: @review.score&.to_f,
      status: @review.status,
      images: image_urls(@review),
      image_ids: image_ids(@review),
      wine_image: wine_image_url,
      published_at: @review.published_at&.iso8601,
      created_at: @review.created_at&.iso8601,
      wine_name: @review.vintage&.wine&.name,
      wine_slug: @review.vintage&.wine&.slug,
      vintage_year: @review.vintage&.year,
      drink_from: @review.drink_from,
      drink_to: @review.drink_to,
      drink_plus: @review.drink_plus
    }
  end

  private

  def image_urls(record)
    return [] unless record.images.attached?

    record.images.map do |image|
      Rails.application.routes.url_helpers.rails_blob_url(image, host: @base_url || "localhost:3000")
    end
  end

  def image_ids(record)
    return [] unless record.images.attached?

    record.images.map(&:id)
  end

  # Fallback picture for list views: the reviewed wine's first image.
  def wine_image_url
    wine = @review.vintage&.wine
    return unless wine&.images&.attached?

    Rails.application.routes.url_helpers.rails_blob_url(wine.images.first, host: @base_url || "localhost:3000")
  end
end
