module Web
  class FinderController < BaseController
    # The wine finder ranks stored wine profiles by how close they are to the
    # user's selected tasting parameters, mirroring the React /finder page.
    # Data comes from the WineProfile model (one source of truth); the ranking
    # runs server-side on submit via a Turbo Frame.
    def index
      @taste_parameters = TasteParameter.sorted_by_label
      @colors = WineProfile.pluck(:color).compact.uniq.sort
    end

    def matches
      @color = params[:color].presence || "All"
      @selected = {}
      @taste_parameters = TasteParameter.sorted_by_label

      @taste_parameters.each do |param|
        value = params["taste_#{param.slug}"].presence
        @selected[param.slug] = value ? value.to_i : 3
      end

      profiles = WineProfile.includes(wine_profile_taste_parameters: :taste_parameter)
      profiles = profiles.where(color: @color) unless @color == "All"
      profiles = profiles.all

      @matches = profiles
        .map { |profile| { profile: profile, score: match_score(profile, @selected) } }
        .sort_by { |entry| -entry[:score] }
        .first(4)

      render layout: false
    end

    private

    # Mirrors calculateMatch in the React Home/Finder: a percentage derived
    # from the total absolute distance across all taste parameters.
    def match_score(profile, selected)
      params = profile.wine_profile_taste_parameters.to_h { |wtp| [ wtp.taste_parameter.slug, wtp.score ] }
      total_distance = @taste_parameters.sum do |param|
        ((params[param.slug] || 3) - selected[param.slug]).abs
      end
      max_distance = @taste_parameters.length * 4
      (100 * (max_distance - total_distance) / max_distance.to_f).round
    end
  end
end
