module TasteParametersHelper
  def taste_parameter_color_class(parameter)
    "taste-parameter-card--#{parameter.label.to_s.parameterize.presence || 'unknown'}"
  end

  def taste_parameter_details(parameter)
    [
      ("Low: #{parameter.low}" if parameter.low.present?),
      ("High: #{parameter.high}" if parameter.high.present?),
      ("Help: #{parameter.help}" if parameter.help.present?)
    ].compact.join(" · ")
  end
end