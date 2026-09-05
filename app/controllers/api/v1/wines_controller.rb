class Api::V1::WinesController < ApplicationController

  # Wine management (create/update/destroy) is restricted to signed-in
  # Super Users and Reviewers; reading stays public.
  before_action :authenticate_user!, only: [:create, :update, :destroy]
  before_action :ensure_wine_manager!, only: [:create, :update, :destroy]
  skip_before_action :authenticate_user!, only: [:index, :show, :search]

  def index
    wines = Wine.includes(producer: [], grapes: [], regions: [], wine_categories: :category).order(:name)
    wines = wines.joins(:grapes).where(grapes: { id: params[:grape_id] }) if params[:grape_id].present?
    wines = wines.joins(:wine_categories).where(wine_categories: { category_id: params[:category_id] }) if params[:category_id].present?
    wines = wines.left_outer_joins(:wine_categories).where(wine_categories: { id: nil }) if params[:uncategorised] == "true"
    wines = wines.joins(:producer).where(producers: { country_id: params[:country_id] }) if params[:country_id].present?
    wines = wines.joins(:wine_regions).where(wine_regions: { region_id: params[:region_id] }) if params[:region_id].present?

    # Vintage counts come from a single grouped query instead of one query
    # per vintage (the old N+1 that dominated the "All Wines" response time).
    vintage_counts = Vintage.where(wine_id: wines).group(:wine_id).count

    return if render_paginated(wines) { |items| serialize_wines(items, vintage_counts) }

    render json: serialize_wines(wines, vintage_counts)
  end

  def serialize_wines(wines, vintage_counts)
    wines.map { |wine| WineListSerializer.new(wine, request.base_url, vintage_counts).as_json }
  end

  # GET /api/v1/wines/grouped?per_group=12
  # Server-side "12 wines per category" view for the All Wines page. Returns
  # up to `per_group` wines per category plus each category's total count,
  # so the response size stays ~12 × #categories regardless of how many
  # thousands of wines exist. Uncategorised (wine_categories.id IS NULL) is
  # grouped under "Uncategorised" and always appears last; category display
  # order mirrors the frontend (sort_order_wine asc with nulls last, then
  # name, Uncategorised last).
  def grouped
    per_group = params[:per_group].to_i
    per_group = 12 if per_group <= 0
    per_group = per_group.clamp(1, 50)

    # One window-function query returns up to `per_group` wines per category
    # (a wine with several categories yields one row per category).
    rows = Wine.find_by_sql([<<~SQL, per_group])
      SELECT sub.* FROM (
        SELECT wines.*, COALESCE(wc.category_id, 0) AS grouped_cat_id,
               ROW_NUMBER() OVER (
                 PARTITION BY COALESCE(wc.category_id, 0)
                 ORDER BY wines.name
               ) AS rn
        FROM wines
        LEFT JOIN wine_categories wc ON wc.wine_id = wines.id
      ) sub
      WHERE sub.rn <= ?
    SQL

    wine_ids = rows.map(&:id).uniq
    wines_by_id = Wine.where(id: wine_ids)
                      .includes(producer: [], grapes: [], regions: [], wine_categories: :category)
                      .index_by(&:id)
    vintage_counts = Vintage.where(wine_id: wine_ids).group(:wine_id).count

    # Bucket each window row into its category group (0 == Uncategorised).
    groups = Hash.new { |h, k| h[k] = [] }
    rows.each do |row|
      cat_id = row.grouped_cat_id == 0 ? nil : row.grouped_cat_id
      groups[cat_id] << WineListSerializer.new(wines_by_id[row.id], request.base_url, vintage_counts).as_json
    end

    # Per-category totals and the uncategorised total, each in one grouped query.
    category_counts = WineCategory.where(category_id: groups.keys.compact).group(:category_id).count
    uncategorised_count =
      if groups.key?(nil)
        Wine.left_outer_joins(:wine_categories).where(wine_categories: { id: nil }).count
      else
        0
      end

    categories = Category.where(id: groups.keys.compact).to_a
    ordered = categories.select { |c| c.sort_order_wine.present? }.sort_by { |c| [c.sort_order_wine, c.name.to_s] }
    unordered = categories.reject { |c| c.sort_order_wine.present? }.sort_by { |c| c.name.to_s }

    result = (ordered + unordered).map do |cat|
      { category: cat.name, count: category_counts[cat.id] || groups[cat.id].size, wines: groups[cat.id] }
    end

    if groups.key?(nil)
      result << { category: "Uncategorised", count: uncategorised_count, wines: groups[nil] }
    end

    render json: result
  end

  def show
    wine = Wine.includes(vintages: [], wine_taste_parameters: :taste_parameter, producer: [], grapes: [], regions: [:country]).find_by!(slug: params[:id])
    render json: WineSerializer.new(wine, request.base_url).as_json
  end

  def create
    @wine = Wine.new(wine_params)
    if @wine.save
      render json: WineSerializer.new(@wine).as_json, status: :created
    else
      render json: { errors: @wine.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @wine = Wine.find_by!(slug: params[:id])
    if @wine.update(wine_params)
      render json: WineSerializer.new(@wine).as_json
    else
      render json: { errors: @wine.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @wine = Wine.find_by!(slug: params[:id])
    @wine.destroy
    head :no_content
  end

  # JSON endpoint used by the article form's "search wines" picker.
  def search
    query = params[:q].to_s.strip
    wines =
      if query.blank?
        Wine.none
      else
        Wine.where("name ILIKE ?", "%#{query}%").includes(:vintages).order(:name).limit(20)
      end

    render json: wines.map { |wine| wine_search_json(wine) }
  end

  private

  def ensure_wine_manager!
    return if current_user&.wine_manager?

    render json: { error: "Forbidden" }, status: :forbidden
  end

    def wine_search_json(wine)
    {
      id: wine.id,
      name: wine.name,
      slug: wine.slug,
      color: wine.color,
      producer: wine.producer ? { id: wine.producer.id, slug: wine.producer.slug, name: wine.producer.name } : nil,
      category: wine.category&.name,
      vintages: wine.vintages.order(year: :desc).map do |vintage|
        { id: vintage.id, year: vintage.year }
      end
    }
  end

  private

  def wine_params
    permitted = params.require(:wine).permit(
      :name, :color, :sparkling, :prompt, :closure, :alcohol_percentage, :volume_ml, :producer_id, :designation_name,
      images: [],
      grape_ids: [],
      region_ids: [],
      category_ids: [],
      vintages_attributes: [:id, :year, :prompt, :price, :no_vintage, :_destroy],
      wine_taste_parameters_attributes: [:id, :taste_parameter_id, :taste_parameter_slug, :score, :_destroy]
    )

    # Convert taste_parameter_slug to taste_parameter_id
    if permitted[:wine_taste_parameters_attributes]
      permitted[:wine_taste_parameters_attributes].each do |attrs|
        if attrs[:taste_parameter_slug].present?
          tp = TasteParameter.find_by(slug: attrs[:taste_parameter_slug])
          attrs[:taste_parameter_id] = tp&.id
          attrs.delete(:taste_parameter_slug)
        end
      end
    end
    permitted
  end
end

