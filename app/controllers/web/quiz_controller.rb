module Web
  class QuizController < BaseController
    # Renders the interactive tasting quiz. Searching a wine profile and the
    # slider-based accuracy check are handled client-side (Stimulus), which
    # mirrors the React quiz and keeps the interaction snappy without a full
    # page reload.
    def index
      @taste_parameters = TasteParameter.sorted_by_label
    end

    # JSON endpoint backing the quiz's wine-profile search-as-you-type.
    # Reuses the same search semantics as GET /api/v1/wine_profiles/search,
    # but keeps the web controller self-contained and returns the parameters
    # the quiz needs for the accuracy comparison.
    def search
      query = params[:q].to_s.strip
      profiles =
        if query.blank?
          WineProfile.none
        else
          WineProfile
            .includes(wine_profile_taste_parameters: :taste_parameter)
            .where(
              "wine_profiles.name ILIKE ? OR wine_profiles.regions::text ILIKE ?",
              "%#{query}%", "%#{query}%"
            )
            .order(:name)
            .limit(10)
        end

      render json: profiles.map { |profile| wine_profile_json(profile) }
    end

    private

    def wine_profile_json(profile)
      WineProfileSerializer.new(profile).as_json
    end
  end
end
