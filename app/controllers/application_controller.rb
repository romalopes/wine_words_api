class ApplicationController < ActionController::Base
  include Api::Paginatable
  include Auditable
  include Impersonable

  # This controller is the base for the JSON API consumed by the React app
  # (cross-origin from localhost:5173 in development). Auth is handled via
  # Bearer JWTs (devise-jwt), not cookies, so CSRF/origin checks are disabled
  # here. Server-rendered Web::* controllers inherit ActionController::Base
  # directly and keep standard CSRF protection.
  skip_forgery_protection

  before_action :authenticate_user!
  # Email-verification lock (feature on only): a user with an unconsumed
  # verification token is locked out of every authenticated endpoint. Once the
  # verification window has passed the lock is absolute until they click a
  # fresh link (request one via the resend endpoint).
  before_action :enforce_email_verification!

  # Private test-access gate: while TEST_ACCESS_PASSWORD is configured, every
  # Api::V1 request must carry a valid signed test-access token (see
  # TestAccess / TestAccessToken). Independent of Devise authentication.
  # (Server-rendered controllers inherit ActionController::Base directly and
  # keep their existing RequireLogin / Devise protection.)
  include TestAccess

  def render_resource(resource)
    if resource.errors.empty?
      render json: resource
    else
      validation_error(resource)
    end
  end

  def validation_error(resource)
    render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
  end

  # Shared admin-only gate for admin controllers. Subclassers still declare
  # `before_action :authenticate_admin!` themselves (e.g. ConfigurationsController,
  # SettingsController) so the guard is explicit per controller.
  def authenticate_admin!
    return render json: { error: "Authentication required" }, status: :unauthorized unless current_user
    return if real_current_user&.admin?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  # See the before_action comment above.
  def enforce_email_verification!
    return unless EmailVerification.require?
    return unless current_user&.email_verification_pending?

    sign_out(current_user) # revokes the JWT via JwtDenylist
    render json: {
      error: "Verify your email address before using the application. " \
             "We sent a verification link to #{current_user.email}.",
      code: "email_verification_pending",
      **EmailVerificationService.pending_payload(current_user)
    }, status: :forbidden
  end
end