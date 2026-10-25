# Digest email for follow-based notifications: one mail per user per period,
# grouped by the content each event refers to (issue #192 phase 8).
class NotificationPreferencesMailer < ApplicationMailer
  layout "mailer"

  def follow_digest(user, notifications, base_url = "")
    @user = user
    @notifications = notifications
    @base_url = base_url

    mail(to: user.email, subject: "Your Wine Words activity digest (#{notifications.size} update#{notifications.size == 1 ? '' : 's'})")
  end
end