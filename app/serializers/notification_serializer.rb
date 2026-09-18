# One notification event (email + future in-app list). Deliberately lean: the
# list UI needs the message, when it was/is due and whether it has been read.
class NotificationSerializer
  def initialize(notification, base_url = nil)
    @notification = notification
    @base_url = base_url
  end

  def as_json
    package = @notification.wine_package

    {
      id: @notification.id,
      notification_type: @notification.notification_type,
      message: @notification.message,
      wine_package_id: @notification.wine_package_id,
      producer_name: package&.producer&.name,
      package_status: package&.status,
      notifiable_type: @notification.notifiable_type,
      notifiable_id: @notification.notifiable_id,
      scheduled_date: @notification.scheduled_date&.iso8601,
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
