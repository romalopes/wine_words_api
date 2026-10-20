# frozen_string_literal: true

# Enqueued after every successful login (email/password or social).
#
# Receives the user's id and the serialisable `LoginDetails` hash so nothing
# from the original request survives into the background job. The mailer is
# delivered via `deliver_later` so the actual SMTP/API call is itself queued.
#
# Failures are logged and retried — they must never bubble back into the
# login response.
class NewLoginNotificationJob < ApplicationJob
  queue_as :background

  # Rails 8.1 renamed the backoff strategy to :polynomially_longer (the old
  # :exponentially_longer symbol was removed and raises at retry time).
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(user_id, details_hash)
    user = User.find_by(id: user_id)
    return if user.nil? || user.email.blank?
    return if details_hash.blank?

    # The plain hash — not the LoginDetails object — is what crosses the job
    # boundary: only plain-JSON types are Active Job-serializable, and that
    # includes the mailer's arguments when `deliver_later` wraps them in
    # MailDeliveryJob. The mailer rehydrates its own LoginDetails.
    SecurityMailer.new_login_email(user, details_hash).deliver_later
  rescue StandardError => e
    Rails.logger.error(
      "[security] new-login notification failed for user #{user_id}: #{e.class}: #{e.message}"
    )
    raise
  end
end
