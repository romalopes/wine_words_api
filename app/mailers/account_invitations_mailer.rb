class AccountInvitationsMailer < ApplicationMailer
  def invitation(invitation, raw_token)
    @invitation = invitation
    @user = invitation.user
    @accept_url = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/accept-invitation#token=#{raw_token}"
    mail(
      to: invitation.email,
      reply_to: MailSender.reply_to,
      subject: "You're invited to Wine Words"
    )
  end
end
