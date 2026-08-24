module Web
  class SessionsController < BaseController
    def new
      redirect_to root_path if user_signed_in?
    end

    def create
      user = User.find_by(email: params[:email])

      if user&.valid_password?(params[:password])
        sign_in(:user, user)
        redirect_to root_path, notice: "Signed in successfully. Welcome back, #{user.email}!"
      else
        flash.now[:alert] = "Invalid email or password."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      sign_out(:user)
      redirect_to login_path, notice: "You have been signed out."
    end
  end
end