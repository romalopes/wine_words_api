class WinesController < ActionController::Base
  layout "application"
  helper :wines
  include RequireLogin

  def index
    @wines = Wine.includes(:vintages, wine_taste_parameters: :taste_parameter).order(:name)
  end

  def show
    @wine = Wine.includes(:vintages, wine_taste_parameters: :taste_parameter).find_by!(slug: params[:id])
  end

  def new
    @wine = Wine.new
  end

  def create
    @wine = Wine.new(wine_params)
    if @wine.save
      attach_images
      redirect_to @wine, notice: "Wine was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @wine = Wine.find_by!(slug: params[:id])
  end

  def update
    @wine = Wine.find_by!(slug: params[:id])
    if @wine.update(wine_params)
      attach_images
      redirect_to @wine, notice: "Wine was successfully updated."
    else
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

  private

  def attach_images
    images = params[:wine][:images]
    @wine.images.attach(images) if images.is_a?(Array)
  end

  private

  def wine_params
    params.require(:wine).permit(
      :name, :region, :color, :prompt, :closure, :alcohol_percentage, :volume_ml, :producer_id,
      vintages_attributes: [:id, :year, :prompt, :_destroy],
      wine_taste_parameters_attributes: [:id, :taste_parameter_id, :taste_parameter_slug, :score, :_destroy]
    )
  end
end