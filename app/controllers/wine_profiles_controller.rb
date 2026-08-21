class WineProfilesController < ActionController::Base
  layout "application"
  helper :wine_profiles

  def index
    @wine_profiles = WineProfile.includes(wine_profile_taste_parameters: :taste_parameter).order(:name)
  end

  def show
    @wine_profile = WineProfile.includes(wine_profile_taste_parameters: :taste_parameter).find_by!(slug: params[:id])
  end

  def new
    @wine_profile = WineProfile.new
  end

  def create
    @wine_profile = WineProfile.new(wine_profile_params)
    if @wine_profile.save
      redirect_to @wine_profile, notice: "Wine profile was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @wine_profile = WineProfile.find_by!(slug: params[:id])
  end

  def update
    @wine_profile = WineProfile.find_by!(slug: params[:id])
    if @wine_profile.update(wine_profile_params)
      redirect_to @wine_profile, notice: "Wine profile was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @wine_profile = WineProfile.find_by!(slug: params[:id])
    @wine_profile.destroy
    redirect_to wine_profiles_url, notice: "Wine profile was successfully destroyed."
  end

  private
    # :slug, :name, :grapes, :regions, :color, :notes, :parameters
    def wine_profile_params
      params.require(:wine_profile).permit(:slug, :name, :grapes, :regions, :color, :notes, :parameters)
    end
end