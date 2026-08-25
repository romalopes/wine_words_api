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
      published_at: @review.published_at&.iso8601,
      created_at: @review.created_at&.iso8601
    }
  end

  private

  def image_urls(record)
    return [] unless record.images.attached?

    record.images.map do |image|
      Rails.application.routes.url_helpers.rails_blob_url(image, host: @base_url || "localhost:3000")
    end
  end
end
