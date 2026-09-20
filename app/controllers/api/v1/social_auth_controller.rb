# Social sign-in endpoints:
#
#   POST /api/v1/auth/google
#   POST /api/v1/auth/apple
#   POST /api/v1/auth/microsoft
#   POST /api/v1/auth/facebook
#
# Each accepts the provider-issued credential plus (for Apple) the nonce:
#
#   { "credential": "<ID token | access token | authorization code>",
#     "nonce": "<optional>" }
#
# The credential is verified server-side; nothing the client claims about
# identity is trusted. Once resolved, the User is signed in through the *same*
# Devise/Warden scope the email/password flow uses, so devise-jwt issues the
# ordinary application JWT and the response payload is identical to a normal
# login. There is no separate social session mechanism.
class Api::V1::SocialAuthController < ApplicationController
  # These endpoints are the sign-in step itself: the caller is anonymous.
  #
  # The action is deliberately NOT named `sign_in`: Devise::Controllers::SignInOut
  # defines a `sign_in(resource_or_scope, *args)` helper on every controller, and
  # overriding it here would make the `sign_in(:user, @user)` call below recurse
  # into the action itself.
  skip_before_action :authenticate_user!, only: :create

  # Private test-access gate (inherited from ApplicationController; restated
  # here to document that social sign-in is gated too).
  include TestAccess

  include Auditable
  include UserSessionPayload

  # Stored action name for the audit trail (descriptions are provider-specific,
  # see log_description).
  audit_actions create: "social_sign_in"

  # POST /api/v1/auth/:provider
  def create
    @user = Authentication::SocialLogin.sign_in(
      provider: provider,
      credential: credential,
      nonce: params[:nonce]
    )

    # Reuses the existing session. devise-jwt's dispatch hook sees this request
    # path (config/initializers/devise.rb) and puts the usual JWT in the
    # Authorization response header.
    sign_in(:user, @user)

    render_user_session(@user, status: :ok)
  rescue Authentication::Error => e
    render json: e.to_h, status: e.status
  end

  # Audit description, e.g. "User logged in with Google".
  def log_description
    "User logged in with #{provider_label}"
  end

  def log_objects
    [ @user ].compact
  end

  private

  def provider
    params[:provider].to_s.downcase
  end

  # Accepts either a top-level credential or a nested { code: ... } payload
  # (Apple's authorization-code flow). Never a provider UID or email.
  def credential
    params[:credential].presence ||
      params.dig(:provider_credential, :credential).presence ||
      params[:token].presence ||
      params[:code].presence
  end

  def provider_label
    UserIdentity::PROVIDER_LABELS[provider] || provider.humanize
  end
end