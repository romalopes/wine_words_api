class Api::V1::SessionsController < Devise::SessionsController
  respond_to :json

  private

  def respond_with(current_user, _opts = {})
    if current_user.persisted?
      render json: {
        user: {
          id: current_user.id,
          email: current_user.email,
          user_name: current_user.user_name,
          roles: current_user.role_names,
          # Parity with GET /users/me: the Subscribe page derives its CTA
          # enablement (Choose plan / Manage subscription) from these fields.
          # Without them the cards render disabled until a hard refresh.
          subscription: current_user.subscription ? { id: current_user.subscription.id, name: current_user.subscription.name } : nil,
          can_manage_billing: Billing.configured?
        }
      }, status: :ok
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end

  def respond_to_on_destroy(_current_user = nil)
    head :no_content
  end
end