# Trade submission confirmation mailer.
#
# Sent when a public trade submission is created. The submitter receives a
# confirmation with their guest access link so they can track the package.
#
# IMPORTANT: the raw guest token is PASSED IN by the controller — the mailer
# must NEVER call generate_guest_token!, because that would rotate the digest
# and invalidate the very link shown in the UI response (404 on next visit).
class TradeSubmissionsMailer < ApplicationMailer
  # @param package_id [Integer] the WinePackage ID
  # @param guest_token [String] the raw one-time guest token returned by the
  #   submission endpoint (only its digest is stored on the package)
  def confirmation(package_id, guest_token)
    @package        = WinePackage.find(package_id)
    @guest_token    = guest_token
    @guest_url      = "#{EmailVerification.frontend_url}/trade/packages/#{@guest_token}"
    @company_name   = @package.contact_snapshot&.dig("company_name")
    @contact_name   = @package.contact_snapshot&.dig("contact_name")
    @wine_count     = @package.items.size
    @wine_names     = @package.items.map { |i| i.snapshot_wine_name }.join(", ")

    mail(
      to: @package.contact_snapshot&.dig("email"),
      subject: "Your Wine Words submission ##{@package.id} — confirmation"
    )
  end

  # Alerts ONE Editor/Admin that a public submission arrived and needs triage.
  #
  # One message per recipient (never a shared To/CC list): staff email addresses
  # are not disclosed to each other, and the deep link is personal.
  #
  # @param package_id [Integer] the WinePackage ID
  # @param recipient_id [Integer] the staff User receiving this copy
  def new_submission(package_id, recipient_id)
    @package         = WinePackage.find(package_id)
    @recipient       = User.find(recipient_id)
    contact          = @package.contact_snapshot || {}
    @company_name    = contact["company_name"]
    @contact_name    = contact["contact_name"]
    @contact_email   = contact["email"]
    @contact_country = contact["country"]
    @contact_role    = contact["role"]
    @wine_count      = @package.items.size
    @wine_names      = @package.items.map { |i| i.snapshot_wine_name }.join(", ")
    @package_url     = "#{EmailVerification.frontend_url}/admin/trade/packages/#{@package.id}"

    mail(
      to: @recipient.email,
      subject: "New trade submission ##{@package.id} — " \
               "#{@company_name.presence || @contact_name.presence || 'Trade submitter'}"
    )
  end
end