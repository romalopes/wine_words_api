class TasteParameterSerializer
  def initialize(taste_parameter)
    @taste_parameter = taste_parameter
  end

  def as_json
    {
      id: @taste_parameter.id,
      slug: @taste_parameter.slug,
      label: @taste_parameter.label,
      labels: @taste_parameter.labels,
      # Retain the established endpoint fields for clients deployed before the
      # five-level UI. They are derived from the canonical labels.
      low: @taste_parameter.label_1,
      high: @taste_parameter.label_5,
      help: @taste_parameter.help,
    }
  end

end