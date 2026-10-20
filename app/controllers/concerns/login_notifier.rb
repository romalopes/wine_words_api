# frozen_string_literal: true

# Shared hook for controllers that complete a successful authentication.
#
#   notify_login!(user:, login_method: "password")
#
# Collects the request metadata (IP, user agent, geolocation) into a
# LoginDetails value object and enqueues the notification email as a
# background job. All failures are logged and swallowed: a problem in the
# notification pipeline must never fail the login response.
#
# Deliberately NOT used for impersonated sessions — an administrator signing
# in on behalf of a user is an administrative action, not a real sign-in, and
# must not alarm the account owner.
module LoginNotifier
  extend ActiveSupport::Concern

  private

  def notify_login!(user:, login_method: "password")
    details = LoginDetailsCollector.collect(request, login_method: login_method)
    NewLoginNotificationJob.perform_later(user.id, details.serializable_hash)
  rescue StandardError => e
    Rails.logger.error("[security] failed to enqueue login notification: #{e.class}: #{e.message}")
    nil
  end
end
