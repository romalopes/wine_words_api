class AccountInvitationService
  COOLDOWN = 1.minute

  class Error < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end

  def self.issue!(user:, actor:)
    invitation = nil
    raw_token = nil
    User.transaction do
      user.lock!
      validate_target!(user)
      enforce_cooldown!(user)

      invitation, raw_token = AccountInvitation.issue!(user:, email: user.email, invited_by: actor)
      invitation.update!(last_delivery_attempt_at: Time.current, delivery_status: "sending", delivery_error_code: nil)
    end
    deliver!(invitation, raw_token)
    invitation
  end

  def self.revoke!(user:, actor:)
    invitation = user.account_invitations.usable.order(created_at: :desc).first
    raise Error.new("no_usable_invitation", "There is no usable invitation to revoke") unless invitation

    invitation.revoke!(actor:)
    invitation
  end

  def self.validate_target!(user)
    raise Error.new("account_not_eligible", "Only unclaimed accounts can be invited") unless user.unclaimed? && !user.deleted?
    raise Error.new("email_required", "Add a valid email address before sending an invitation") if user.email.blank?
    raise Error.new("account_suspended", "Suspended accounts cannot be invited") if user.suspended?
  end
  private_class_method :validate_target!

  def self.enforce_cooldown!(user)
    latest_attempt = user.account_invitations.maximum(:last_delivery_attempt_at)
    return unless latest_attempt && latest_attempt > COOLDOWN.ago

    retry_after = (latest_attempt + COOLDOWN - Time.current).ceil
    raise Error.new("invitation_rate_limited", "Try again in #{retry_after} seconds")
  end
  private_class_method :enforce_cooldown!

  def self.deliver!(invitation, raw_token)
    AccountInvitationsMailer.invitation(invitation, raw_token).deliver_now
    invitation.update!(status: :sent, sent_at: Time.current, delivery_status: "accepted")
  rescue StandardError => e
    invitation&.update_columns(
      delivery_status: "failed",
      delivery_error_code: e.class.name.to_s.first(255),
      updated_at: Time.current
    )
    raise Error.new("invitation_delivery_failed", "The invitation was created but email delivery failed")
  end
  private_class_method :deliver!
end
