class Api::V1::SessionsController < Devise::SessionsController
  respond_to :json

  private

  def respond_with(current_user, _opts = {})
    if current_user.persisted?
      render json: {
        user: { id: current_user.id, email: current_user.email, name: current_user.name, roles: current_user.role_names }
      }, status: :ok
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end

  def respond_to_on_destroy(_current_user = nil)
    head :no_content
  end
end