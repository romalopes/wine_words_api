# Connected sign-in methods for the signed-in User:
#
#   GET    /api/v1/auth/identities           list connected providers
#   POST   /api/v1/auth/identities/:provider connect a provider
#   DELETE /api/v1/auth/identities/:id       disconnect a provider
#
# These endpoints never create a User, an Account, a role or a subscription:
# they only attach an external authentication identity to the User who is
# already authenticated. The User's Account, roles, subscription and Stripe
# customer therefore cannot change by linking a provider.
class Api::V1::UserIdentitiesController < ApplicationController
  include Auditable
  audit_actions create: "social_identity_connected",
                destroy: "social_identity_disconnected"

  before_action :set_identity, only: :destroy

  # GET /api/v1/auth/identities
  def index
    render json: {
      identities: current_user.user_identities.order(:provider, :created_at).map { |i| identity_json(i) },
      # True when the User has a password as well as (or instead of) social
      # sign-ins — the UI uses it to warn before disconnecting the last one.
      password_authentication: current_user.password_authentication?
    }
  end

  # POST /api/v1/auth/identities/:provider
  def create
    identity = Authentication::SocialLogin.connect(
      user: current_user,
      provider: params[:provider].to_s.downcase,
      credential: credential,
      nonce: params[:nonce]
    )
    @identity = identity

    render json: { identity: identity_json(identity) }, status: :created
  rescue Authentication::Error => e
    render json: e.to_h, status: e.status
  end

  # DELETE /api/v1/auth/identities/:id
  def destroy
    # A User must always keep at least one way to sign in.
    if last_authentication_method?
      return render json: {
        error: "Add another sign-in method before disconnecting this one.",
        code: :last_authentication_method
      }, status: :conflict
    end

    @identity.destroy
    head :no_content
  end

  # e.g. "Google identity connected" / "Microsoft identity disconnected"
  def log_description
    label = UserIdentity::PROVIDER_LABELS[audited_provider] || audited_provider.to_s.humanize
    action_name == "create" ? "#{label} identity connected" : "#{label} identity disconnected"
  end

  def log_objects
    [ current_user ].compact
  end

  private

  # The provider involved, whether it came from the path (create) or from the
  # row being removed (destroy).
  def audited_provider
    action_name == "create" ? params[:provider].to_s.downcase : @identity&.provider
  end

  def set_identity
    # Scoped to the current User so one person can never delete another
    # person's identity.
    @identity = current_user.user_identities.find_by(id: params[:id])
    return if @identity

    render json: { error: "Not found" }, status: :not_found
  end

  # Removing this identity would leave the User with no way to authenticate.
  def last_authentication_method?
    !current_user.password_authentication? && current_user.user_identities.count <= 1
  end

  def credential
    params[:credential].presence ||
      params.dig(:provider_credential, :credential).presence ||
      params[:token].presence ||
      params[:code].presence
  end

  def identity_json(identity)
    {
      id: identity.id,
      provider: identity.provider,
      label: identity.label,
      email: identity.email,
      created_at: identity.created_at
    }
  end
end