class ProducersController < ActionController::Base
  layout "application"
  helper :producers
  include RequireLogin

  # Only Super Users and Reviewers may add, edit, delete or link wines.
  before_action :set_producer, only: [:show, :edit, :update, :destroy, :link_wine]
  before_action :deny_unless_wine_manager!, only: [:new, :create, :edit, :update, :destroy, :link_wine]
  helper_method :can_manage_producers?

  def index
    @producers = Producer.includes(:wines).order(:name)
  end

  def show
    # @producer set by before_action
  end

  def new
    @producer = Producer.new
  end

  def create
    @producer = Producer.new(producer_params)
    if @producer.save
      @producer.images.attach(params[:producer][:images]) if params[:producer][:images].present?
      redirect_to @producer, notice: "Producer was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # @producer set by before_action
  end

  def update
    if @producer.update(producer_params)
      @producer.images.attach(params[:producer][:images]) if params[:producer][:images].present?
      redirect_to @producer, notice: "Producer was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @producer.destroy
    redirect_to producers_url, notice: "Producer was successfully destroyed."
  end

  # POST /producers/:id/link_wine (wine_id may be a slug or numeric id).
  def link_wine
    wine = Wine.find_by(slug: params[:wine_id]) || Wine.find_by(id: params[:wine_id])
    unless wine
      redirect_to @producer, alert: "Wine not found." and return
    end

    previous = wine.producer
    wine.update!(producer: @producer)

    notice =
      if previous && previous.id != @producer.id
        "#{wine.name} was reassigned from #{previous.name} to #{@producer.name}."
      else
        "#{wine.name} was linked to #{@producer.name}."
      end
    redirect_to @producer, notice: notice
  end

  private

  def set_producer
    @producer = Producer.includes(:wines).find_by!(slug: params[:id])
  end

  # Authorisation for producer management (Super User or Reviewer only).
  def can_manage_producers?
    user_signed_in? && current_user.wine_manager?
  end

  def deny_unless_wine_manager!
    return if can_manage_producers?

    redirect_to producers_path, alert: "You are not allowed to manage producers."
    false
  end

  def producer_params
    params.require(:producer).permit(:name, :address, :email, :website, :description,
                                     :producer_type, :instagram, :facebook)
  end
end