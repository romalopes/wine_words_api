# frozen_string_literal: true

# Sends the "new sign-in to your account" notification email after every
# successful login. Receives the User record and the login details as the
# plain serialisable hash produced by LoginDetails#serializable_hash (never
# the LoginDetails object itself — the mailer runs inside MailDeliveryJob,
# whose arguments must be plain-JSON serialisable — and rehydrates the value
# object locally). This keeps the mailer decoupled from HTTP concerns and
# testable in isolation.
class SecurityMailer < ApplicationMailer
  # Notification: "New sign-in to your Wine Words account".
  def new_login_email(user, details_hash)
    @user = user
    @details = LoginDetails.new(**details_hash.symbolize_keys)
    @reset_password_url = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/reset-password"

    subject = "New sign-in to your Wine Words account"
    mail(
      to: user.email,
      subject: subject
    )
  end
end
