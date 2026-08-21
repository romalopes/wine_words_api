module ReviewsHelper
  def review_status_class(review)
    "review--#{review.status.to_s.parameterize.presence || 'draft'}"
  end

  def review_score(review)
    return "No score" if review.score.blank?

    "#{review.score} / 100"
  end
end