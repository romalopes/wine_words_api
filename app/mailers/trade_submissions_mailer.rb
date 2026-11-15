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
end