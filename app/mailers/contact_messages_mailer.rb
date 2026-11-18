# Alerts ONE configured contact recipient (CONTACT_NOTIFICATION_EMAILS) that a
# public contact message arrived (IDENTITY_209 Phase 2).
#
# Headers:
#   From     -> MailSender.from (MAIL_FROM), shared with every other mailer
#   Reply-To -> the sender's validated address, so replying in a normal mail
#               client answers the visitor directly
#   To       -> exactly one configured recipient (never a shared list, so
#               internal addresses are not disclosed to each other)
#
# MAIL_REPLY_TO is deliberately NOT used here: it keeps its existing
# application-wide meaning (see lib/mail_sender.rb and CustomDeviseMailer).
#
# All user-controlled values are interpolated into the views, which escape them;
# the subject strips CR/LF to make header injection impossible.
class ContactMessagesMailer < ApplicationMailer
  def notification(contact_message_id, recipient_email)
    @contact_message = ContactMessage.find(contact_message_id)
    @recipient_email = recipient_email
    @contact_type_label = @contact_message.contact_type.tr("_", " ")
    @submitted_at = @contact_message.created_at.utc.strftime("%Y-%m-%d %H:%M UTC")
    @inbox_url = "#{EmailVerification.frontend_url}/settings/contact-messages/#{@contact_message.id}"

    mail(
      to: recipient_email,
      reply_to: @contact_message.email,
      subject: "New contact message — #{sanitized_subject}"
    )
  end

  private

  # Subject lines must never contain raw newlines (header injection).
  def sanitized_subject
    @contact_message.subject.to_s.gsub(/[\r\n]+/, " ").strip
  end
end
