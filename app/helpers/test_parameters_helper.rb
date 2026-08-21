module TestParametersHelper
  def test_parameter_color_class(parameter)
    "test-parameter-card--#{parameter.label.to_s.parameterize.presence || 'unknown'}"
  end
end