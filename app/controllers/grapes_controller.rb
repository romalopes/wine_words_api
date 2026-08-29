class GrapesController < ActionController::Base
  layout "application"
  include RequireLogin

  before_action :set_grape, only: [:show, :edit, :update, :destroy]
  before_action :ensure_grape_manager!, only: [:new, :edit, :create, :update, :destroy]

  def index
    @grapes = sort_grapes(Grape.all)
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

  def show; end

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
    @grape = Grape.find(params[:id])
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