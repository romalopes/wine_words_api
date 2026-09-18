# Daily review-deadline reminders for wine packages.
#
# Two responsibilities, in order:
#   1. top up the 15/5/0-day notifications for every active package — the
#      scheduler is idempotent (unique index on package/type/due date), so
#      running twice changes nothing;
#   2. deliver every notification that has come due and not yet been sent.
#
# Delivery is skipped for packages that are no longer active, so a package
# completed (or cancelled/rejected) after its reminders were scheduled never
# emails the reviewer. A single bad address or provider hiccup is logged and
# skipped: it must never stop the batch (same contract as
# Billing::ReconcileSubscriptionsJob).
class WinePackages::SendReviewDeadlineNotificationsJob < ApplicationJob
  queue_as :background

  def perform(today = Date.current)
    today = today.to_date

    schedule_reminders(today)
    deliver_due(today)
  end

  private

  def schedule_reminders(today)
    WinePackage.active.where.not(review_deadline: nil).find_each do |package|
      WinePackages::Notifications::Schedule.call(package, at: today)
    rescue StandardError => e
      Rails.logger.error(
        "[WinePackages] scheduling reminders failed for package #{package&.id}: #{e.class}: #{e.message}"
      )
      sleep(0.2)
    end
  end

  def deliver_due(today)
    Notification.undelivered
                .where(notification_type: WinePackages::Notifications::DEADLINE_TYPE)
                .where(scheduled_date: ..today)
                .includes(:recipient, wine_package: :producer)
                .find_each do |notification|
      deliver(notification)
    rescue StandardError => e
      Rails.logger.error(
        "[WinePackages] delivering notification #{notification&.id} failed: #{e.class}: #{e.message}"
      )
      sleep(0.2)
    end
  end

  def deliver(notification)
    package = notification.wine_package

    # Orphaned reminder (its package is gone): mark it sent so it stops being
    # picked up forever.
    return notification.mark_sent! if package.nil?
    return unless package_active?(package)

    recipient = notification.recipient
    return if recipient&.email.blank?

    WinePackagesMailer.review_deadline_notification(notification).deliver_now
    notification.mark_sent!
  end

  def package_active?(package)
    !package.completed? && !package.cancelled? && !package.rejected?
  end
end
