module WinesHelper
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
