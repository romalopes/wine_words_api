module WineProfilesHelper
  def wine_profile_color_class(profile)
    "wine-profile-card--#{profile.color.to_s.parameterize.presence || 'unknown'}"
  end

  def wine_profile_details(profile)
    [
      ("#{profile.grapes}" if profile.grapes.present?),
      ("#{profile.regions}" if profile.regions.present?),
      ("#{profile.serving}" if profile.serving.present?)
    ].compact.join(" · ")
  end
end