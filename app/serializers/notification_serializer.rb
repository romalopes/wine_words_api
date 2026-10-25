# One notification delivery (email reminders + follow-based in-app events).
# Deliberately lean: the list UI needs the message, when it was/is due, whether
# it has been read, and — for follow notifications (issue #192) — where to link
# (target_path) and what happened (event_type, actor_name). Legacy package
# fields stay so the existing UI keeps working unchanged.
class NotificationSerializer
  def initialize(notification, base_url = nil)
    @notification = notification
    @base_url = base_url
  end

  def as_json
    package = @notification.wine_package
    event = @notification.notification_event

    {
      id: @notification.id,
      notification_type: @notification.notification_type,
      message: @notification.message,
      wine_package_id: @notification.wine_package_id,
      producer_name: package&.producer&.name,
      package_status: package&.status,
      notifiable_type: @notification.notifiable_type,
      notifiable_id: @notification.notifiable_id,
      # Follow-based (issue #192) fields — nil for package reminders.
      notification_event_id: @notification.notification_event_id,
      event_type: event&.event_type,
      actor_name: @notification.actor&.display_name,
      target_path: @notification.target_path,
      target_label: @notification.target_label,
      scheduled_date: @notification.scheduled_date&.iso8601,
      delivered_at: iso(@notification.delivered_at),
      sent_at: iso(@notification.sent_at),
      read_at: iso(@notification.read_at),
      sent: @notification.sent?,
      read: @notification.read?,
      created_at: iso(@notification.created_at)
    }
  end

  private

  def iso(time)
    time&.iso8601
  end
end
