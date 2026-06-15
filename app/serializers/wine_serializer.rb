class WineSerializer
  def initialize(wine)
    @wine = wine
  end

  def as_json
    {
      id: @wine.id,
      slug: @wine.slug,
      name: @wine.name,
      region: @wine.region,
      color: @wine.color,
      closure: @wine.closure,
      alcohol_percentage: @wine.alcohol_percentage&.to_f,
      volume_ml: @wine.volume_ml,
      prompt: @wine.prompt,
      parameters: parameters,
      vintages: @wine.vintages.order(year: :desc).map do |v|
        {
          id: v.id,
          year: v.year,
          prompt: v.prompt
        }
      end
    }
  end

  private

  def parameters
    # @wine.wine_taste_parameters.to_h do |wtp|
    #   [wtp.taste_parameter.slug, wtp.score]
    # end
    @wine.wine_taste_parameters.map do |wtp|
    {
      id: wtp.id,
      taste_parameter_id: wtp.taste_parameter_id,
      taste_parameter_slug: wtp.taste_parameter.slug,
      score: wtp.score
    }
end
  end
end