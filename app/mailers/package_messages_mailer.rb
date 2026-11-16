# Alerts one person that a new message landed on a trade submission.
#
# The same mailer serves both directions:
#   * a submitter message → one copy per Editor/Admin,
#   * an editorial reply  → the submitter's account, or the contact address of
#     a guest submission (no account to notify in-app).
#
# One email per recipient (never a shared To/CC list), so addresses are not
# disclosed and the deep link is personal.
class PackageMessagesMailer < ApplicationMailer
  STAFF_ROLES = %w[Admin Editor].freeze

  # @param package [WinePackage]
  # @param recipient [User] the account receiving this copy
  # @param message [WinePackageMessage]
  def new_message(package, recipient, message)
    assign_common(package, message)
    @recipient = recipient
    @staff_recipient = staff?(recipient)
    @url = @staff_recipient ? admin_url : submitter_url

    mail(to: recipient.email, subject: subject_line)
  end

  # Guest submissions have no User; the contact address on the submission gets
  # the reply instead.
  def new_message_to_contact(package, message)
    assign_common(package, message)
    @recipient = nil
    @staff_recipient = false
    @url = submitter_url

    mail(
      to: contact_email(package),
      subject: subject_line,
      template_name: "new_message"
    )
  end

  private

  def assign_common(package, message)
    @package = package
    @message = message
    @body = message.body.to_s
    contact = package.contact_snapshot || {}
    @company_name = contact["company_name"]
    @contact_name = contact["contact_name"]
    @sender_name = message.sender&.display_name.presence ||
                   message.sender&.email.presence ||
                   "Wine Words"
  end

  def staff?(user)
    user.present? && user.catalogue_manager?
  end

  def contact_email(package)
    (package.contact_snapshot || {})["email"]
  end

  def subject_line
    "New message on trade submission ##{@package.id}"
  end

  def admin_url
    "#{EmailVerification.frontend_url}/admin/trade/packages/#{@package.id}"
  end

  def submitter_url
    "#{EmailVerification.frontend_url}/trade/my-packages/#{@package.id}"
  end
end
