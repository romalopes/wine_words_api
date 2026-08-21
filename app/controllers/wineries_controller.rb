class WineriesController < ActionController::Base
  layout "application"
  helper :wineries

  def index
    @wineries = Winery.includes(:wines).order(:name)
  end

  def show
    @winery = Winery.includes(:wines).find_by!(slug: params[:id])
  end

  def new
    @winery = Winery.new
  end

  def create
    @winery = Winery.new(winery_params)
    if @winery.save
      redirect_to @winery, notice: "Winery was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @winery = Winery.find_by!(slug: params[:id])
  end

  def update
    @winery = Winery.find_by!(slug: params[:id])
    if @winery.update(winery_params)
      redirect_to @winery, notice: "Winery was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @winery = Winery.find_by!(slug: params[:id])
    @winery.destroy
    redirect_to wineries_url, notice: "Winery was successfully destroyed."
  end

  private

  def winery_params
    params.require(:winery).permit(:name, :address, :email)
  end
end