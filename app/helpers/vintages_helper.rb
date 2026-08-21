module VintagesHelper
  def vintage_color_class(vintage)
    "vintage-card--#{vintage.year.to_s.presence || 'unknown'}"
  end
end