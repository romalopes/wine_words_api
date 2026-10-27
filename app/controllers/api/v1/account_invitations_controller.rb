class Api::V1::AccountInvitationsController < ApplicationController
  before_action :require_catalogue_manager!
  before_action :load_user
  before_action :require_manageable_target!
  audit_actions create: "invitation_sent", resend: "invitation_resent", revoke: "invitation_revoked"

  def index
    render json: @user.account_invitations.order(created_at: :desc).map { |invitation| invitation_json(invitation) }
  end

  def create
    @invitation = AccountInvitationService.issue!(user: @user, actor: real_current_user)
    render json: invitation_json(@invitation), status: :created
  rescue AccountInvitationService::Error => e
    render_service_error(e)
  end

  def resend
    create
  end

  def revoke
    @invitation = AccountInvitationService.revoke!(user: @user, actor: real_current_user)
    render json: invitation_json(@invitation)
  rescue AccountInvitationService::Error => e
    render_service_error(e)
  end

  private

  def require_catalogue_manager!
    head :forbidden unless real_current_user&.catalogue_manager?
  end

  def load_user
    @user = User.find(params[:user_id])
  end

  def require_manageable_target!
    return if real_current_user.admin?
    return unless @user.roles.where(name: %w[Admin Editor]).exists?

    head :forbidden
  end

  def render_service_error(error)
    status = error.code == "invitation_rate_limited" ? :too_many_requests : :unprocessable_entity
    render json: { error: error.message, code: error.code }, status:
  end

  def invitation_json(invitation)
    {
      id: invitation.id,
      email: invitation.email,
      status: invitation.status,
      usable: invitation.usable?,
      expires_at: invitation.expires_at,
      sent_at: invitation.sent_at,
      accepted_at: invitation.accepted_at,
      revoked_at: invitation.revoked_at,
      delivery_status: invitation.delivery_status,
      delivery_error_code: invitation.delivery_error_code,
      invited_by: invitation.invited_by && { id: invitation.invited_by.id, display_name: invitation.invited_by.display_name },
      revoked_by: invitation.revoked_by && { id: invitation.revoked_by.id, display_name: invitation.revoked_by.display_name },
      created_at: invitation.created_at
    }
  end

  def log_description
    %(#{action_name.humanize} invitation for "#{@user&.display_name}")
  end

  def log_objects
    [ real_current_user, @user, @invitation ].compact
  end
end
