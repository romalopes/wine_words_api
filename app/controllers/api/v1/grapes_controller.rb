class Api::V1::GrapesController < ApplicationController
  audit_actions :create, :update, :destroy

  # Server-side ordering for count sorts: correlated subqueries over the
  # grape_id-indexed join tables. Kept GROUP BY-free on purpose —
  # `render_paginated` counts via `scope.except(:select, :order).count`,
  # which a grouped scope would break (hash instead of a scalar).
  # `grapes.id ASC` breaks ties so page boundaries stay stable.
  WINES_COUNT_ORDER =
    "(SELECT COUNT(*) FROM wine_grapes WHERE wine_grapes.grape_id = grapes.id) DESC, grapes.id ASC".freeze
  PRODUCERS_COUNT_ORDER =
    "(SELECT COUNT(*) FROM producer_grapes WHERE producer_grapes.grape_id = grapes.id) DESC, grapes.id ASC".freeze

  def log_description
    "#{audit_verb} grape \"#{@grape.name}\""
  end

  def log_objects
    [@grape].compact
  end

  before_action :authenticate_user!, except: [:index, :show, :search]
  before_action :ensure_wine_manager!, only: [:create, :update, :destroy, :link_wine]
  before_action :set_grape, only: [:show, :update, :destroy, :link_wine]

  def index
    scope = sorted_scope
    scope = apply_search_filter(scope)
    return if render_paginated(scope) { |items| grapes_list_json(items) }

    render json: grapes_list_json(scope)
  end

  def search
    query = params[:q].to_s.strip
    grapes =
      if query.blank?
        Grape.none
      else
        term = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        Grape.where("name ILIKE ? OR array_to_string(synonyms, ',') ILIKE ?", term, term).order(:name).limit(20)
      end
    render json: grapes.map { |grape| { id: grape.id, name: grape.name, color: grape.color, synonyms: grape.synonyms } }
  end

  def show
    render json: grape_json(@grape)
  end

  def link_wine
    wine = Wine.find_by(slug: params[:wine_id]) || Wine.find_by(id: params[:wine_id])
    unless wine
      return render json: { error: "Wine not found" }, status: :not_found
    end

    wine.grapes << @grape unless wine.grapes.include?(@grape)
    render json: grape_json(@grape)
  end

  # POST /api/v1/grapes/:id/link_producer — add the producer to this grape.
  def link_producer
    return render json: { error: "Forbidden" }, status: :forbidden unless current_user&.wine_manager?

    producer = Producer.find_by(slug: params[:producer_id]) || Producer.find_by(id: params[:producer_id])
    return render json: { error: "Producer not found" }, status: :not_found unless producer

    producer.grapes << @grape unless producer.grapes.include?(@grape)
    render json: { id: @grape.id, name: @grape.name, linked: true }
  end

  def create
    grape = Grape.new(grape_params)
    if grape.save
      render json: grape, status: :created
    else
      render json: { errors: grape.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @grape.update(grape_params)
      render json: @grape
    else
      render json: { errors: @grape.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @grape.destroy
    head :no_content
  end

  private

  def set_grape
    @grape = Grape.find_by(slug: params[:id]) || Grape.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Grape not found" }, status: :not_found
  end

  def grape_params
    params.require(:grape).permit(
      :name, :color, :origin_country, :is_blending_grape, :serving, :relevance,
      main_regions: [], synonyms: [], notes: []
    )
  end

  # `?sort=wines_count` / `?sort=producers_count` order by the link counts;
  # anything else (including blank) keeps the relevance default.
  def sorted_scope
    case params[:sort]
    when "wines_count"
      Grape.order(Arel.sql(WINES_COUNT_ORDER))
    when "producers_count"
      Grape.order(Arel.sql(PRODUCERS_COUNT_ORDER))
    else
      Grape.relevance_order
    end
  end

  # `?q=` free-text filter for the /grapes list page (name, synonyms and
  # origin country). Matches the producers index `?q=` behaviour; `%` / `_`
  # in the term are escaped so they match literally.
  def apply_search_filter(scope)
    query = params[:q].to_s.strip
    return scope if query.blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    scope.where(
      "grapes.name ILIKE ? OR array_to_string(grapes.synonyms, ',') ILIKE ? OR grapes.origin_country ILIKE ?",
      term, term, term,
    )
  end

  # Bulk-serialize a whole (possibly paginated) list of grapes: two grouped
  # COUNT queries for the page's ids instead of one COUNT per record.
  # `grape.wines.size` on an unloaded through-association fires its own query
  # — 40 per page at per_page=20, which against the remote dev DB cost ~8 s
  # per request (and ~40 s for the legacy no-param full list).
  def grapes_list_json(scope)
    grapes = scope.to_a
    ids = grapes.map(&:id)
    wine_counts = WineGrape.where(grape_id: ids).group(:grape_id).count
    producer_counts = ProducerGrape.where(grape_id: ids).group(:grape_id).count
    grapes.map do |grape|
      grape_json(
        grape,
        wine_counts: wine_counts.fetch(grape.id, 0),
        producer_counts: producer_counts.fetch(grape.id, 0),
      )
    end
  end

  def grape_json(grape, wine_counts: nil, producer_counts: nil)
    data = grape.as_json
    # List paths pass bulk precomputed counts (2 queries total, see
    # grapes_list_json); single-record paths (show/link_wine) fall back to
    # `.size`. Unique [wine_id, grape_id] / [producer_id, grape_id] indexes
    # and FKs keep the join-row counts identical to the through-association
    # counts they replace.
    data["wines_count"] = wine_counts || grape.wines.size
    data["producers_count"] = producer_counts || grape.producers.size
    # Wines are NOT embedded here. The React grape screens fetch them
    # separately via GET /api/v1/wines?grape_id=... (paginated, lean
    # WineListSerializer). Embedding every wine with the full WineSerializer
    # used to cost one query per image/category/vintage-count (2195 queries
    # and a 179 s response for chardonnay) for data no client reads.
    data
  end

  def ensure_wine_manager!
    return if current_user&.wine_manager?
    render json: { error: "Forbidden" }, status: :forbidden
  end
end
