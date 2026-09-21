class Api::V1::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  include Auditable
  # Private test-access gate (this controller inherits Devise, not
  # ApplicationController, so the concern is included directly).
  include TestAccess
  # Sign-up is a meaningful auditable event (it creates a new user).
  audit_actions :create

  # Sign-up. When email verification is required the account is created but NO
  # session is issued: the user receives a verification email (auto-send on by
  # default) and the response carries the verification deadline so the frontend
  # can show "check your inbox" messaging.
  def create
    build_resource(sign_up_params)
    resource.save
    yield resource if block_given?

    if resource.persisted?
      if EmailVerification.require?
        EmailVerificationService.send_verification(resource) if EmailVerification.auto_send_on_signup?
        render json: {
          user: session_user_json(resource),
          email_verification: EmailVerificationService.pending_payload(resource)
        }, status: :created
      else
        sign_in(resource_name, resource)
        respond_with(resource)
      end
    else
      clean_up_passwords resource
      respond_with(resource)
    end
  end

  private

  # The user this sign-up attempt is about: the freshly signed-in user after
  # a successful sign-up, the (unpersisted) resource on failure, and nil when
  # the request never produced a resource (e.g. malformed params).
  def audit_user
    current_user || (resource if resource&.persisted?)
  end

  def log_description
    user = audit_user
    user ? "New user signed up: #{user.user_name} (#{user.email})" : "Failed sign-up attempt"
  end

  def log_objects
    [audit_user].compact
  end

  def sign_up_params
    params.require(:user).permit(:user_name, :email, :password, :password_confirmation)
  end

  def respond_with(current_user, _opts = {})
    if current_user.persisted?
      render json: { user: session_user_json(current_user) }, status: :created
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Shared authenticated-user payload for both the session-issuing path and the
  # verification-pending path.
  def session_user_json(user)
    current_sub = user.user_subscriptions.current.first

    {
      id: user.id,
      email: user.email,
      user_name: user.user_name,
      roles: user.role_names,
      # Parity with GET /users/me so the Subscribe page can derive its
      # CTA enablement immediately without a hard refresh.
      subscription: user.subscription ? { id: user.subscription.id, name: user.subscription.name } : nil,
      billing_provider: current_sub&.billing_provider,
      can_manage_billing: Billing.configured?,
      subscription_status: current_sub&.status,
    }
  end
end
