module WineriesHelper
  def winery_color_class(winery)
    "winery-card--#{winery.name.to_s.parameterize.presence || 'unknown'}"
  end

  def winery_details(winery)
    [
      winery.address.presence,
      winery.email.presence
    ].compact.join(" · ")
  end
end