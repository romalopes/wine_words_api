class TestParametersController < ActionController::Base
  layout "application"
  helper :test_parameters

  def index
    @test_parameters = TestParameter.includes(:wine_taste_parameters).order(:label)
  end

  def show
    @test_parameter = TestParameter.includes(:wine_taste_parameters).find_by!(slug: params[:id])
  end

  def new
    @test_parameter = TestParameter.new
  end

  def create
    @test_parameter = TestParameter.new(test_parameter_params)
    if @test_parameter.save
      redirect_to @test_parameter, notice: "Test parameter was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @test_parameter = TestParameter.find_by!(slug: params[:id])
  end

  def update
    @test_parameter = TestParameter.find_by!(slug: params[:id])
    if @test_parameter.update(test_parameter_params)
      redirect_to @test_parameter, notice: "Test parameter was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @test_parameter = TestParameter.find_by!(slug: params[:id])
    @test_parameter.destroy
    redirect_to test_parameters_url, notice: "Test parameter was successfully destroyed."
  end

  private
    # :slug, :label, :low, :high
    def test_parameter_params
      params.require(:test_parameter).permit(:slug, :label, :low, :high)
    end
end