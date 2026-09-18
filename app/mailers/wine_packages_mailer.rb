# Deadline reminder email for a wine package.
#
# Sent by WinePackages::SendReviewDeadlineNotificationsJob from a Notification
# row, which already carries the recipient, the due date and the message. The
# mailer therefore only formats: it never decides who to notify or when.
class WinePackagesMailer < ApplicationMailer
  def review_deadline_notification(notification)
    @notification = notification
    @package = notification.wine_package
    @recipient = notification.recipient
    @producer = @package&.producer
    @deadline = @package&.review_deadline
    @pending_count = @package&.pending_review_count
    @pending_items = @package ? @package.pending_review_items : []
    @days_until_deadline = days_until_deadline(notification)
    @package_url = package_url

    mail(to: @recipient.email, subject: subject_line)
  end

  private

  # Measured on the day the reminder goes out, so a 15-day reminder reads
  # "in 15 days" regardless of when the package actually arrived.
  def days_until_deadline(notification)
    return nil if @deadline.blank? || notification.scheduled_date.blank?

    (@deadline - notification.scheduled_date).to_i
  end

  def subject_line
    producer = @producer&.name || "Wine package"

    case @days_until_deadline
    when nil then "#{producer}: wine package review deadline"
    when 0 then "#{producer}: wine package review deadline is today"
    else "#{producer}: wine package review deadline in #{@days_until_deadline} " \
         "#{'day'.pluralize(@days_until_deadline)}"
    end
  end

  # Links into the React app (FRONTEND_URL), matching the password-reset mailer.
  def package_url
    base = ENV.fetch("FRONTEND_URL", "http://localhost:5173")
    return base if @package.nil?

    "#{base}/wine-packages/#{@package.id}"
  end
end
