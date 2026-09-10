class Api::V1::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  private

  def sign_up_params
    params.require(:user).permit(:user_name, :email, :password, :password_confirmation)
  end

  def respond_with(current_user, _opts = {})
    if current_user.persisted?
      current_sub = current_user.user_subscriptions.current.first
      render json: {
        user: {
          id: current_user.id,
          email: current_user.email,
          user_name: current_user.user_name,
          roles: current_user.role_names,
          # Parity with GET /users/me so the Subscribe page can derive its
          # CTA enablement (Choose plan / Manage subscription / Current plan)
          # immediately after sign-up without a hard refresh.
          subscription: current_user.subscription ? { id: current_user.subscription.id, name: current_user.subscription.name } : nil,
          billing_provider: current_sub&.billing_provider,
          can_manage_billing: Billing.configured?,
          subscription_status: current_sub&.status,
        }
      }, status: :created
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
