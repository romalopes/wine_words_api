class Api::V1::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  private

  def sign_up_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end

  def respond_with(current_user, _opts = {})
    if current_user.persisted?
      render json: {
        user: { id: current_user.id, email: current_user.email, name: current_user.name, roles: current_user.role_names }
      }, status: :created
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end
end