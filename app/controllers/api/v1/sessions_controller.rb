class Api::V1::SessionsController < Devise::SessionsController
  respond_to :json

  include Auditable
  include UserSessionPayload
  include LoginNotifier
  include TurnstileVerifiable
  # Private test-access gate (this controller inherits Devise, not
  # ApplicationController, so the concern is included directly).
  include TestAccess
  audit_actions :create, :destroy

  before_action :remember_user_for_audit

  def log_description
    if action_name == "create"
      @audit_user ? "User logged in" : "Login attempt"
    else
      @audit_user ? "User logged out" : "Logout"
    end
  end

  def log_objects
    [ @audit_user ].compact
  end

  def remember_user_for_audit
    @audit_user = current_user
  end

  # Sign-in with Turnstile verification
  def create
    # Verify Turnstile before processing the sign-in
    # Token is nested under user.turnstile_token per Devise conventions
    turnstile_token = params.dig(:user, :turnstile_token)
    return unless verify_turnstile!(action: "login", token: turnstile_token)

    super
  end

  private

  def respond_with(current_user, _opts = {})
    if current_user.persisted?
      # Email-verification gate: an unverified user gets NO session. The JWT
      # Devise just put on the response is revoked immediately, and the 403
      # carries the deadline so the frontend can show "check your inbox" with
      # how long the user still has to verify (or that the link expired).
      if EmailVerification.require? && current_user.email_verification_pending?
        sign_out(current_user)
        render json: {
          error: email_verification_error_message(current_user),
          code: "email_verification_pending",
          **EmailVerificationService.pending_payload(current_user)
        }, status: :forbidden
        return
      end

      # Successful sign-in: notify the account owner in the background. This
      # never raises — a notification failure cannot fail the login response.
      notify_login!(user: current_user, login_method: "password")

      render_user_session(current_user, status: :ok)
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end

  def respond_to_on_destroy(_current_user = nil)
    head :no_content
  end

  def email_verification_error_message(user)
    if user.email_verification_expired?
      "Your verification window has expired, so this account is locked. " \
        "Request a new verification email, then click the link to sign in."
    else
      "Please verify your email address before signing in. " \
        "We sent a verification link to #{user.email}."
    end
  end

  # Permit turnstile_token in the sign-in parameters
  def sign_in_params
    params.require(:user).permit(:email, :password, :remember_me, :turnstile_token)
  end
end
