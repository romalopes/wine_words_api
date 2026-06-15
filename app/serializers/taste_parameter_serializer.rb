class TasteParameterSerializer
  def initialize(taste_parameter)
    @taste_parameter = taste_parameter
  end

  def as_json
    {
      id: @taste_parameter.id,
      slug: @taste_parameter.slug,
      label: @taste_parameter.label,
      low: @taste_parameter.low,
      high: @taste_parameter.high,
      help: @taste_parameter.help,
    }
  end

end