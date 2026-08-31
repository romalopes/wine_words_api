module WinesHelper
  # Super Users, Reviewers and Editors may manage wines.
  def can_manage_wines?
    user_signed_in? && current_user.wine_manager?
  end

  def wine_color_class(wine)
    "wine-card--#{wine.color.to_s.parameterize.presence || 'unknown'}"
  end

  def wine_details(wine)
    [
      ("#{wine.alcohol_percentage}% ABV" if wine.alcohol_percentage.present?),
            wine.volume_label,
      wine.closure.presence
    ].compact.join(" · ")
  end
end
