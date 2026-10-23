module TasteParametersHelper
  def taste_parameter_color_class(parameter)
    "taste-parameter-card--#{parameter.label.to_s.parameterize.presence || 'unknown'}"
  end

  def taste_parameter_details(parameter)
    [
      ("1: #{parameter.label_1}" if parameter.label_1.present?),
      ("5: #{parameter.label_5}" if parameter.label_5.present?),
      ("Help: #{parameter.help}" if parameter.help.present?)
    ].compact.join(" · ")
  end
end