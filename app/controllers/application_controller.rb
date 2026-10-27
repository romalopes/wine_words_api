class ApplicationController < ActionController::Base
  include Api::Paginatable
  include Api::RelatedFeed
  include Auditable
  include Impersonable

  # This controller is the base for the JSON API consumed by the React app
  # (cross-origin from localhost:5173 in development). Auth is handled via
  # Bearer JWTs (devise-jwt), not cookies, so CSRF/origin checks are disabled
  # here. Server-rendered Web::* controllers inherit ActionController::Base
  # directly and keep standard CSRF protection.
  skip_forgery_protection

  before_action :authenticate_user!
  # Soft-deleted accounts (issue #195) are rejected on every authenticated
  # request regardless of token freshness — the denylist only covers the token
  # present at deletion time, so this guard is the authoritative server-side
  # enforcement of the deletion lifecycle.
  before_action :reject_deleted_user!
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

  before_action :set_sentry_context
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

  # Soft-deleted accounts (issue #195): any authenticated request from a user
  # with a deleted_at stamp is refused. sign_out also revokes the presented
  # JWT via JwtDenylist, so the client must re-authenticate (which fails,
  # because Devise lookups happen through User scope and deleted users are
  # filtered from authentication).
  def reject_deleted_user!
    return unless current_user&.deleted?

    sign_out(current_user) # revokes the JWT via JwtDenylist
    render json: { error: "This account has been deleted.", code: "account_deleted" },
           status: :forbidden
  end

  # See the before_action comment above.
  def enforce_email_verification!
    return unless EmailVerification.require?
    return unless current_user&.email_verification_pending?

    sign_out(current_user) # revokes the JWT via JwtDenylist
    render json: {
      error: email_verification_error_message(current_user),
      code: "email_verification_pending",
      **EmailVerificationService.pending_payload(current_user)
    }, status: :forbidden
  end
  private

  def email_verification_error_message(user)
    if user.email_verification_expired?
      "Your verification window has expired, so this account is locked. " \
        "Request a new verification email, then click the link to sign in."
    else
      "Verify your email address before using the application. " \
        "We sent a verification link to #{user.email}."
    end
  end

  def set_sentry_context
    if current_user.present?
      Sentry.set_user(id: current_user.id)
      tier = current_user.try(:account_tier) || current_user.try(:tier) || "unknown"
      Sentry.set_tags(user_id: current_user.id.to_s, account_tier: tier)
    else
      # sentry-ruby 7.x requires a Hash for set_user/set_tags; passing nil
      # raises ArgumentError. Clear any stale context with empty hashes.
      Sentry.set_user({})
      Sentry.set_tags({})
    end
  end
end
