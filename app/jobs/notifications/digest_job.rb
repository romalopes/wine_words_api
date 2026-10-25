# Daily/weekly digest of follow-based notifications (issue #192 phase 8).
# One email per user per period: every follow notification that has not been
# emailed yet (sent_at NULL), grouped by the content it refers to. After a
# successful send the rows are marked sent (sent_at) so a digest never
# repeats — while the in-app feed keeps its delivered_at state untouched.
class Notifications::DigestJob < ApplicationJob
  queue_as :notifications

  def perform(cadence = "daily")
    due_scope =
      if cadence == "weekly"
        NotificationPreference.where(digest_cadence: %w[daily weekly])
      else
        # Daily run sends digests for daily users only; weekly ones wait for
        # the weekly run.
        NotificationPreference.where(digest_cadence: "daily")
      end

    due_scope.find_each do |preference|
      deliver_digest(preference)
    rescue StandardError => e
      record_failure(preference, e)
    end
  end

  private

  def deliver_digest(preference)
    user = preference.user
    return if user&.email.blank?

    notifications = undelivered_by_email(user).order(:created_at).to_a
    return if notifications.empty?

    begin
      NotificationPreferencesMailer.follow_digest(user, notifications, base_url).deliver_now
    rescue StandardError
      now = Time.current
      Notification.where(id: notifications.map(&:id)).update_all(failed_at: now, updated_at: now)
      raise
    end

    now = Time.current
    Notification.where(id: notifications.map(&:id))
                .update_all(sent_at: now, failed_at: nil, updated_at: now)
    preference.update!(digest_last_sent_at: now, digest_last_error: nil, digest_last_error_at: nil)
  end

  # Follow-based rows only (event-tied), never package reminders.
  def undelivered_by_email(user)
    user.notifications
        .delivered
        .undelivered
        .where.not(notification_event_id: nil)
  end

  def base_url
    options = ActionMailer::Base.default_url_options
    host = options[:host].to_s
    return "" if host.blank?

    "#{options[:protocol] || "https"}://#{host}"
  end

  def record_failure(preference, error)
    Rails.logger.error(
      "[Notifications] digest failed for user #{preference.user_id}: #{error.class}: #{error.message}"
    )
    preference.update!(digest_last_error_at: Time.current,
                       digest_last_error: "#{error.class}: #{error.message}")
  end
end