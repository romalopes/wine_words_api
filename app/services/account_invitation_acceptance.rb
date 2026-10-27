class AccountInvitationAcceptance
  class Error < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end

  def self.validate(raw_token)
    invitation = AccountInvitation.find_usable_by_token(raw_token)
    return nil unless invitation

    user = invitation.user
    return nil unless eligible?(invitation, user)

    { invitation:, user: }
  end

  def self.accept!(raw_token:, password:, password_confirmation:)
    invitation = AccountInvitation.find_by(token_digest: AccountInvitation.digest_token(raw_token.to_s))
    raise Error.new("invalid_invitation", "This invitation is invalid or has expired") unless invitation

    user = nil
    AccountInvitation.transaction do
      invitation.lock!
      user = invitation.user
      user.lock!
      raise Error.new("invalid_invitation", "This invitation is invalid or has expired") unless eligible?(invitation, user)

      user.password = password
      user.password_confirmation = password_confirmation
      user.account_status = :active
      user.email_verified_at ||= Time.current if user.respond_to?(:email_verified_at)
      user.save!

      invitation.update!(status: :accepted, accepted_at: Time.current)
      user.account_invitations.usable.where.not(id: invitation.id).update_all(
        status: "revoked", revoked_at: Time.current, updated_at: Time.current
      )
    end
    user
  rescue ActiveRecord::RecordInvalid => e
    raise Error.new("validation_failed", e.record.errors.full_messages.join(", "))
  end

  def self.eligible?(invitation, user)
    invitation.usable? && user.unclaimed? && !user.deleted? &&
      user.email.present? && invitation.email.casecmp?(user.email)
  end
  private_class_method :eligible?
end
