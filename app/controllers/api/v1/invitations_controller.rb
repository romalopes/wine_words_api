class Api::V1::InvitationsController < ApplicationController
  skip_before_action :authenticate_user!, :reject_deleted_user!, :enforce_email_verification!
  rate_limit to: 30, within: 1.minute, by: -> { request.remote_ip }, with: -> { render json: { error: "Too many requests", code: "rate_limited" }, status: :too_many_requests }

  def validate
    result = AccountInvitationAcceptance.validate(params[:token])
    return render_invalid unless result

    render json: {
      valid: true,
      invitation: {
        email: masked_email(result[:invitation].email),
        display_name: result[:user].display_name,
        expires_at: result[:invitation].expires_at
      }
    }
  end

  def accept
    user = AccountInvitationAcceptance.accept!(
      raw_token: params[:token],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )
    render json: { message: "Your account is active. Sign in with your email and password.", email: user.email }
  rescue AccountInvitationAcceptance::Error => e
    render json: { error: e.message, code: e.code }, status: :unprocessable_entity
  end

  private

  def render_invalid
    render json: { valid: false, error: "This invitation is invalid or has expired", code: "invalid_invitation" },
           status: :unprocessable_entity
  end

  def masked_email(email)
    local, domain = email.to_s.split("@", 2)
    return nil unless local && domain

    "#{local.first}#{'*' * [ local.length - 1, 1 ].max}@#{domain}"
  end
end
