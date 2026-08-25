module Web
  class RegistrationsController < BaseController
    def new
      redirect_to root_path if user_signed_in?
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      if @user.save
        sign_in(:user, @user)
        redirect_to root_path, notice: "Welcome to Wine Words, #{@user.email}! Your account has been created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end
  end
end