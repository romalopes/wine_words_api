module WineProfiles
  # Assigns a new Wine the closest matching WineProfile and copies its taste
  # parameters into the wine.
  #
  # Order of preference:
  #   1. an explicit wine_profile_id
  #   2. profile name matches the wine name (exact -> contained -> trigram)
  #   3. profile grape varieties overlap the wine's grapes
  #
  # The copied rows are a snapshot: they are created now and never re-synced
  # from the profile if it changes later.
  class AutoAssign
    NAME_SIMILARITY_THRESHOLD = 0.4

    def self.call(wine) = new(wine).call

    def initialize(wine)
      @wine = wine
    end

    def call
      # An explicit profile_id was submitted: honour it, and still copy its
      # taste parameters when the user did not send any.
      if explicit_profile?
        profile = wine.wine_profile
        copy_taste_parameters(profile) if profile
        return wine
      end

      profile = closest_by_name || closest_by_grapes
      return wine unless profile

      wine.wine_profile = profile
      copy_taste_parameters(profile)
      wine
    end

    private

    attr_reader :wine

    # An explicit profile_id was submitted - honour it even when the user sent
    # no taste parameters, and never override an explicit choice with a match.
    def explicit_profile?
      wine.wine_profile_id.present?
    end

    def closest_by_name
      name = wine.name.to_s.strip
      return nil if name.blank?

      exact = WineProfile.where(
        "LOWER(wine_profiles.name) = LOWER(?)",
        name
      ).first
      return exact if exact

      contained = WineProfile.where(
        "? ILIKE '%' || wine_profiles.name || '%'",
        name
      ).order(Arel.sql("LENGTH(wine_profiles.name) DESC")).first
      return contained if contained

      fuzzy = WineProfile
        .where(
          "similarity(wine_profiles.name, ?) >= ?",
          name,
          NAME_SIMILARITY_THRESHOLD
        )
        .order(
          Arel.sql(
            "similarity(wine_profiles.name, #{Wine.connection.quote(name)}) DESC, " \
            "wine_profiles.name ASC"
          )
        )
        .first
      fuzzy
    end

    def closest_by_grapes
      grape_ids = wine.wine_grapes.map(&:grape_id).compact.presence || wine.grape_ids
      return nil if grape_ids.blank?

      profile = WineProfile
        .joins(:wine_profile_grapes)
        .where(wine_profile_grapes: { grape_id: grape_ids })
        .group("wine_profiles.id")
        .order(
          Arel.sql("COUNT(wine_profile_grapes.grape_id) DESC"),
          Arel.sql(
            "COUNT(wine_profile_grapes.grape_id)::float / " \
            "NULLIF((SELECT COUNT(*) FROM wine_profile_grapes wpgs " \
            "WHERE wpgs.wine_profile_id = wine_profiles.id), 0) DESC"
          ),
          colour_match_sql,
          Arel.sql("wine_profiles.name ASC")
        )
        .first
      profile
    end

    def colour_match_sql
      Arel.sql(
        "CASE WHEN LOWER(wine_profiles.color) = LOWER(?) THEN 1 ELSE 0 END",
        wine.color.to_s.downcase
      )
    end

    def copy_taste_parameters(profile)
      existing_ids = wine.wine_taste_parameters.pluck(:taste_parameter_id)

      profile
        .wine_profile_taste_parameters
        .where.not(score: nil)
        .where.not(taste_parameter_id: existing_ids)
        .find_each do |profile_parameter|
          wine.wine_taste_parameters.build(
            taste_parameter_id: profile_parameter.taste_parameter_id,
            score: profile_parameter.score
          )
        end
    end
  end
end
