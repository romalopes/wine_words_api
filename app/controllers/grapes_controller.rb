class GrapesController < ActionController::Base
  layout "application"
  include RequireLogin

  before_action :set_grape, only: [:show, :edit, :update, :destroy, :link_wine, :producers]
  before_action :ensure_grape_manager!, only: [:new, :edit, :create, :update, :destroy]

  def link_wine
    unless current_user&.wine_manager?
      return redirect_to @grape, alert: "You are not allowed to manage wines."
    end
    wine = Wine.find_by(slug: params[:wine_id]) || Wine.find_by(id: params[:wine_id])
    unless wine
      return redirect_to @grape, alert: "Wine not found."
    end

    if wine.grapes.include?(@grape)
      redirect_to @grape, notice: "#{wine.name} is already linked to #{@grape.name}."
    else
      wine.grapes << @grape
      redirect_to @grape, notice: "#{wine.name} was added to #{@grape.name}."
    end
  end

  def producers
    per_page = 20
    producer_scope = @grape.producers
      .includes(:wines, :country, :logo_attachment)
      .order(:name)
    @producer_count = producer_scope.count
    @producer_total_pages = (@producer_count.to_f / per_page).ceil
    @producer_page = (params[:producer_page] || 1).to_i
    @producer_page = 1 if @producer_page < 1 || @producer_page > [@producer_total_pages, 1].max
    @producers = producer_scope
      .limit(per_page)
      .offset((@producer_page - 1) * per_page)
  end

  def index
    @grapes = sort_grapes(Grape.includes(:wines, :producers).all)
  end

  def search
    query = params[:q].to_s.strip
    grapes =
      if query.blank?
        Grape.none
      else
        Grape.where("name ILIKE ? OR array_to_string(synonyms, ',') ILIKE ?", "%#{query}%", "%#{query}%").order(:name).limit(20)
      end
    render json: grapes.map { |grape| { id: grape.id, name: grape.name, color: grape.color, synonyms: grape.synonyms } }
  end

  def show
    @wines = @grape.wines.includes(:producer, :regions, :vintages).order(:name)
  end

  def new
    @grape = Grape.new
  end

  def create
    @grape = Grape.new(grape_params)
    if @grape.save
      redirect_to grapes_path, notice: "Grape was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @grape.update(grape_params)
      redirect_to grapes_path, notice: "Grape was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @grape.destroy
    redirect_to grapes_path, notice: "Grape was successfully destroyed."
  end

  private

  def ensure_grape_manager!
    return if @current_user&.super_admin? || @current_user&.editor?
    redirect_to grapes_path, alert: "Only Super Users and Editors can manage grapes."
  end

  def set_grape
    @grape = Grape.find_by(slug: params[:id]) || Grape.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to grapes_path, alert: "Grape not found."
  end

  def grape_params
    params.require(:grape).permit(
      :name, :color, :origin_country, :is_blending_grape, :serving, :relevance,
      main_regions: [], synonyms: [], notes: []
    ).tap do |permitted|
      permitted[:main_regions] = parse_array_param(params[:grape][:main_regions])
      permitted[:synonyms] = parse_array_param(params[:grape][:synonyms])
      permitted[:notes] = parse_array_param(params[:grape][:notes])
    end
  end

  def parse_array_param(param)
    return [] if param.blank?
    if param.is_a?(Array)
      param.reject(&:blank?)
    else
      param.split(",").map(&:strip).reject(&:blank?)
    end
  end

  def sort_grapes(grapes)
    case params[:sort_by]
    when "name"
      grapes.order(:name)
    when "origin_country"
      grapes.order(:origin_country, :name)
    else
      grapes.relevance_order
    end
  end
end