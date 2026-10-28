class Api::V1::WineProfilesController < ApplicationController
  include Api::Paginatable
  audit_actions :create, :update, :destroy

  def log_description
    "#{audit_verb} wine profile \"#{@wine_profile.name}\""
  end

  def log_objects
    [@wine_profile].compact
  end

  skip_before_action :authenticate_user!, only: [:index, :show, :search]
  def index
    scope = WineProfile.includes(:profile_grapes, :profile_regions, wine_profile_taste_parameters: :taste_parameter)
    if render_paginated(scope) { |wines| wines.map { |wine| WineProfileSerializer.new(wine).as_json } }
      # rendered by render_paginated
    else
      # Fallback for legacy clients that don't send page param
      render json: scope.map { |wine| WineProfileSerializer.new(wine).as_json }
    end
  end

  def show
    wine_profile = WineProfile.find_by!(slug: params[:id])
    render json: WineProfileSerializer.new(wine_profile).as_json
  end

  def create
    @wine_profile = WineProfile.new(wine_profile_params.except(:grapes, :regions))
    if @wine_profile.save
      assign_grapes_and_regions
      render json: @wine_profile, status: :created
    else
      render json: @wine_profile.errors, status: :unprocessable_entity
    end
  end

  def update
    @wine_profile = WineProfile.find_by!(slug: params[:id])
    if @wine_profile.update(wine_profile_params.except(:grapes, :regions))
      assign_grapes_and_regions
      render json: @wine_profile
    else
      render json: @wine_profile.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @wine_profile = WineProfile.find_by!(slug: params[:id])
    @wine_profile.destroy
    head :no_content
  end

  def search_with_llm_interpreted
    query = params[:q].to_s.strip
    if query.blank?
      render json: { wines: [], wine_profiles: [], llm_interpreted: nil } and return
    end

    limit = params[:limit]&.to_i || 10
    sim_threshold = 0.2
    word_sim_threshold = 0.3

    # ── Step 1: Ask Ollama to interpret the query ──────────────────────
    llm = LlmSearchService.call(query)

    # ── Step 2: Build search terms from LLM interpretation ─────────────
    # Combine all LLM-extracted terms into searchable queries
    search_terms = (llm[:name_hints] + llm[:region_hints] + llm[:style_notes]).uniq.compact

    # Fall back to the raw query if LLM extracted nothing useful
    search_terms = [query] if search_terms.empty?

    # ── Step 3: pg_trgm search using each extracted term ───────────────
    # Build OR conditions: any term can match name OR region
    wine_conditions = []
    wine_values     = []
    profile_conditions = []
    profile_values     = []

    search_terms.each do |term|
      # wines: match by name
      wine_conditions << "(similarity(wines.name, ?) > ? OR strict_word_similarity(?, wines.name) > ? OR word_similarity(?, wines.name) > ?)"
      wine_values.concat([term, sim_threshold, term, sim_threshold, term, word_sim_threshold])

      # wine_profiles: match by name or regions (JSON text)

      profile_conditions << "(similarity(wine_profiles.name, ?) > ? OR strict_word_similarity(?, wine_profiles.name) > ? OR word_similarity(?, wine_profiles.name) > ? OR EXISTS (SELECT 1 FROM wine_profile_regions wpr JOIN regions r ON r.id = wpr.region_id WHERE wpr.wine_profile_id = wine_profiles.id AND (similarity(r.name, ?) > ? OR strict_word_similarity(?, r.name) > ? OR word_similarity(?, r.name) > ?)))"
      profile_values.concat([term, sim_threshold, term, sim_threshold, term, word_sim_threshold,
                              term, sim_threshold, term, sim_threshold, term, word_sim_threshold])
    end

    # If LLM extracted a color, also filter by it
    if llm[:color].present?
      wine_conditions << "lower(wines.color) = lower(?)"
      wine_values << llm[:color]
      profile_conditions << "lower(wine_profiles.color) = lower(?)"
      profile_values << llm[:color]
    end

    # Build ORDER BY: rank by best trigram match across all search terms
    quoted_terms = search_terms.map { |t| ActiveRecord::Base.connection.quote(t) }
    wine_order_expr = quoted_terms.map do |qt|
      "GREATEST(similarity(wines.name, #{qt}), strict_word_similarity(#{qt}, wines.name), word_similarity(#{qt}, wines.name) * 0.8)"
    end.join(", ")

    profile_order_expr = quoted_terms.map do |qt|
      "GREATEST(similarity(wine_profiles.name, #{qt}), strict_word_similarity(#{qt}, wine_profiles.name), word_similarity(#{qt}, wine_profiles.name) * 0.8, similarity(COALESCE(wine_profiles.regions::text, ''), #{qt}) * 0.7, strict_word_similarity(#{qt}, COALESCE(wine_profiles.regions::text, '')) * 0.7, word_similarity(#{qt}, COALESCE(wine_profiles.regions::text, '')) * 0.6)"
    end.join(", ")

    wines = Wine.includes(wine_taste_parameters: :taste_parameter, vintages: [])
                .where(wine_conditions.join(" OR "), *wine_values)
                .order(Arel.sql("GREATEST(#{wine_order_expr}) DESC"))
                .limit(limit)

    wine_profiles = WineProfile.includes(:profile_grapes, :profile_regions, wine_profile_taste_parameters: :taste_parameter)
                               .where(profile_conditions.join(" OR "), *profile_values)
                               .order(Arel.sql("GREATEST(#{profile_order_expr}) DESC"))
                               .limit(limit)

    render json: {
      wines: wines.map { |w| WineSerializer.new(w).as_json },
      wine_profiles: wine_profiles.map { |wp| WineProfileSerializer.new(wp).as_json },
      llm_interpreted: {
        original_query: query,
        name_hints: llm[:name_hints],
        region_hints: llm[:region_hints],
        color: llm[:color],
        style_notes: llm[:style_notes]
      }
    }
  end

  def search_with_similarities
    query = params[:q].to_s.strip
    if query.blank?
      render json: { wines: [], wine_profiles: [] } and return
    end

    limit = params[:limit]&.to_i || 10

    sim_threshold = 0.2
    word_sim_threshold = 0.3

    quoted_query = ActiveRecord::Base.connection.quote(query)

    # Search wines by name AND region
    wines = Wine.includes(wine_taste_parameters: :taste_parameter, vintages: [])
                .where(
                  "(similarity(wines.name, ?) > ? OR strict_word_similarity(?, wines.name) > ? OR word_similarity(?, wines.name) > ?)",
                  query, sim_threshold,
                  query, sim_threshold,
                  query, word_sim_threshold
                )
                .order(
                  Arel.sql("GREATEST(
                    similarity(wines.name, #{quoted_query}),
                    strict_word_similarity(#{quoted_query}, wines.name),
                    word_similarity(#{quoted_query}, wines.name) * 0.8
                  ) DESC")
                )
                .limit(limit)

    # Search wine_profiles by name AND regions (JSON text)
    wine_profiles = WineProfile.includes(:profile_grapes, :profile_regions, wine_profile_taste_parameters: :taste_parameter)
                               .where(
                                 "(similarity(wine_profiles.name, ?) > ? OR strict_word_similarity(?, wine_profiles.name) > ? OR word_similarity(?, wine_profiles.name) > ?) OR (EXISTS (SELECT 1 FROM wine_profile_regions wpr JOIN regions r ON r.id = wpr.region_id WHERE wpr.wine_profile_id = wine_profiles.id AND (similarity(r.name, ?) > ? OR strict_word_similarity(?, r.name) > ? OR word_similarity(?, r.name) > ?)))",
                                 query, sim_threshold,
                                 query, sim_threshold,
                                 query, word_sim_threshold,
                                 query, sim_threshold,
                                 query, sim_threshold,
                                 query, word_sim_threshold
                               )
                               .order(
                                 Arel.sql("GREATEST(
                                   similarity(wine_profiles.name, #{quoted_query}),
                                   strict_word_similarity(#{quoted_query}, wine_profiles.name),
                                   word_similarity(#{quoted_query}, wine_profiles.name) * 0.8,


                                    COALESCE((SELECT MAX(word_similarity(#{quoted_query}, regions.name))
                                              FROM wine_profile_regions
                                              INNER JOIN regions ON regions.id = wine_profile_regions.region_id
                                              WHERE wine_profile_regions.wine_profile_id = wine_profiles.id), 0) * 0.6
                                 ) DESC")
                               )
                               .limit(limit)

    render json: {
      wines: wines.map { |w| WineSerializer.new(w).as_json },
      wine_profiles: wine_profiles.map { |wp| WineProfileSerializer.new(wp).as_json }
    }
  end

  def search
    try { search_with_llm_interpreted } rescue try { search_with_similarities }

  end

  private

  PERMITTED_PARAMS = [:name, :color, :notes, :serving, {grapes: []}, {regions: []}, :parameters].freeze

  def wine_profile_params
    params.require(:wine_profile).permit(PERMITTED_PARAMS)
  end

  def assign_grapes_and_regions
    grape_names = params[:wine_profile][:grapes] || []
    region_names = params[:wine_profile][:regions] || []

    grapes = Grape.where(name: grape_names)
    regions = Region.where(name: region_names)

    @wine_profile.profile_grapes = grapes
    @wine_profile.profile_regions = regions

    # Keep the denormalized array columns in sync with the associations.
    @wine_profile.grapes = grapes.map(&:name)
    @wine_profile.regions = regions.map(&:name)
    @wine_profile.save! if @wine_profile.changed?
  end
end

