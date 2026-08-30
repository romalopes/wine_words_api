class WinesController < ActionController::Base
  layout "application"
  helper :wines
  include RequireLogin

  # Only Super Users and Reviewers may add, edit or delete wines.
  before_action :deny_unless_wine_manager!, only: [:new, :create, :edit, :update, :destroy, :purge_image]
  helper_method :can_manage_wines?

  def index
    @wines = Wine.includes(:vintages, :grapes, :regions, wine_taste_parameters: :taste_parameter).order(:name)
    if params[:category].present?
      @wines = @wines.joins(:category).where(categories: { name: params[:category] })
    end
    if params[:producer].present?
      @wines = @wines.joins(:producer).where(producers: { slug: params[:producer] })
    end
  end

  def show
    @wine = Wine.includes(:vintages, :grapes, :regions, wine_taste_parameters: :taste_parameter).find_by!(slug: params[:id])
  end

        def new
    @wine = Wine.new(
      color: Wine::DEFAULT_COLOR,
      closure: Wine::DEFAULT_CLOSURE,
      alcohol_percentage: Wine::DEFAULT_ALCOHOL_PERCENTAGE,
      volume_ml: Wine::DEFAULT_VOLUME,
    )
    @taste_parameters = TasteParameter.sorted_by_label
    @wine_categories = Category.where(for_wine: true).order("sort_order_wine asc, name asc")
  end

  def edit
    @wine = Wine.find_by!(slug: params[:id])
    @taste_parameters = TasteParameter.sorted_by_label
    @wine_categories = Category.where(for_wine: true).order("sort_order_wine asc, name asc")
  end

  def create
    @wine = Wine.new(wine_params)
    if @wine.save
      attach_images
      prune_wine_taste_parameters
      redirect_to @wine, notice: "Wine was successfully created."
    else
      @taste_parameters = TasteParameter.sorted_by_label
      @wine_categories = Category.where(for_wine: true).order("sort_order_wine asc, name asc")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @wine = Wine.find_by!(slug: params[:id])
    @taste_parameters = TasteParameter.sorted_by_label
  end

  def update
    @wine = Wine.find_by!(slug: params[:id])
    if @wine.update(wine_params)
      attach_images
      prune_wine_taste_parameters
      redirect_to @wine, notice: "Wine was successfully updated."
    else
      @taste_parameters = TasteParameter.sorted_by_label
      @wine_categories = Category.where(for_wine: true).order("sort_order_wine asc, name asc")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @wine = Wine.find_by!(slug: params[:id])
    @wine.destroy
    redirect_to wines_url, notice: "Wine was successfully destroyed."
  end

  def purge_image
    @wine = Wine.find_by!(slug: params[:id])
    attachment = @wine.images.find_by(id: params[:image_id])
    attachment&.purge
    redirect_to edit_wine_path(@wine.slug), notice: "Image removed."
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

  # JSON endpoint used by the article form: published reviews of one vintage.
  # Content managers (editor/reviewer/super user) can link any published review
  # of the vintage; regular users only see their own.
  def vintage_reviews
    wine = Wine.find_by!(slug: params[:wine_id])
    vintage = wine.vintages.find(params[:vintage_id])
    reviews = vintage.reviews.published
    reviews = reviews.where(user: current_user) unless current_user&.wine_manager?
    reviews = reviews.order(:title)

    render json: reviews.map do |review|
      {
        id: review.id,
        title: review.title.presence || "#{wine.name} #{vintage.year}",
        score: review.score&.to_f
      }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Vintage not found" }, status: :not_found
  end

  # Authorisation for wine management (Super User or Reviewer only).
  def can_manage_wines?
    user_signed_in? && current_user.wine_manager?
  end

  def deny_unless_wine_manager!
    return if can_manage_wines?

    redirect_to wines_path, alert: "You are not allowed to manage wines."
    false
  end

  private

  def wine_search_json(wine)
    {
      id: wine.id,
      name: wine.name,
      slug: wine.slug,
      color: wine.color,
      vintages: wine.vintages.order(year: :desc).map do |vintage|
        { id: vintage.id, year: vintage.year }
      end
    }
  end

  private

  def attach_images
    images = params[:wine][:images]
    @wine.images.attach(images) if images.is_a?(Array)
  end

  # Removes any taste-parameter rows whose taste_parameter_id was not part of
  # the submitted set, keeping the wine in sync with the form sliders.
  def prune_wine_taste_parameters
    submitted_ids = Array(params[:wine][:wine_taste_parameters_attributes])
                      .map { |attrs| attrs[:taste_parameter_id].to_i }
                      .reject(&:zero?)

    @wine.wine_taste_parameters
         .where.not(taste_parameter_id: submitted_ids)
         .destroy_all
  end

  private

  def wine_params
        params.require(:wine).permit(
      :name, :color, :prompt, :closure, :alcohol_percentage, :volume_ml, :producer_id, :category_id, :sparkling,
      grape_ids: [],
      region_ids: [],
      vintages_attributes: [:id, :year, :prompt, :price, :no_vintage, :_destroy],
      wine_taste_parameters_attributes: [:id, :taste_parameter_id, :taste_parameter_slug, :score, :_destroy]
    )
  end
end