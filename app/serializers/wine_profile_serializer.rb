class WineProfileSerializer
  def initialize(wine_profile)
    @wine_profile = wine_profile
  end

  def as_json
    {
      id: @wine_profile.id,
      slug: @wine_profile.slug,
      name: @wine_profile.name,
      grapes: @wine_profile.profile_grapes.map(&:name),
      regions: @wine_profile.profile_regions.map(&:name),
      color: @wine_profile.color,
      notes: @wine_profile.notes,
      serving: @wine_profile.serving,
      parameters: parameters
    }
  end

  private

  def parameters
    @wine_profile.wine_profile_taste_parameters.to_h do |wtp|
      [wtp.taste_parameter.slug, wtp.score]
    end
  end
end