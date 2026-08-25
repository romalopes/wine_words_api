class ProducersController < ActionController::Base
  layout "application"
  helper :producers
  include RequireLogin

  def index
    @producers = Producer.includes(:wines).order(:name)
  end

  def show
    @producer = Producer.includes(:wines).find_by!(slug: params[:id])
    # @producer = Producer.find_by!(id: params[:id])
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
    @producer = Producer.find_by!(slug: params[:id])
  end

  def update
    @producer = Producer.find_by!(slug: params[:id])
    if @producer.update(producer_params)
      @producer.images.attach(params[:producer][:images]) if params[:producer][:images].present?
      redirect_to @producer, notice: "Producer was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @producer = Producer.find_by!(slug: params[:id])
    @producer.destroy
    redirect_to producers_url, notice: "Producer was successfully destroyed."
  end

  private

  def producer_params
    params.require(:producer).permit(:name, :address, :email)
  end
end