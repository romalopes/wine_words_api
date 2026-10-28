class WineProfileSerializer
  def initialize(wine_profile)
    @wine_profile = wine_profile
  end

  def as_json
    {
      id: @wine_profile.id,
      slug: @wine_profile.slug,
      name: @wine_profile.name,
      grapes: grapes,
      regions: regions,
      profile_grapes: profile_grapes,
      profile_regions: profile_regions,
      color: @wine_profile.color,
      notes: @wine_profile.notes,
      serving: @wine_profile.serving,
      parameters: parameters
    }
  end

  private

  # Prefer the denormalized array columns; fall back to the associations when
  # the columns have not been populated (legacy rows).
  def grapes
    @wine_profile.grapes.presence || @wine_profile.profile_grapes.map(&:name)
  end

  def regions
    @wine_profile.regions.presence || @wine_profile.profile_regions.map(&:name)
  end

  # Link objects for client-side navigation to /grapes/:slug and /regions/:slug.
  def profile_grapes
    @wine_profile.profile_grapes.map do |grape|
      { id: grape.id, slug: grape.slug, name: grape.name }
    end
  end

  def profile_regions
    @wine_profile.profile_regions.map do |region|
      { id: region.id, slug: region.slug, name: region.name }
    end
  end

  def parameters
    @wine_profile.wine_profile_taste_parameters.to_h do |wtp|
      [wtp.taste_parameter.slug, wtp.score]
    end
  end
end