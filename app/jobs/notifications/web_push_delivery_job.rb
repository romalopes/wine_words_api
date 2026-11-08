require "web_push"

class Notifications::WebPushDeliveryJob < ApplicationJob
  queue_as :background

  def perform(notification_id)
    notification = Notification.includes(recipient: [ :notification_preference, :push_subscriptions ])
                               .find_by(id: notification_id)
    return unless notification&.delivered?

    recipient = notification.recipient
    return unless NotificationPreference.for(recipient).push_enabled?
    return if vapid_public_key.blank? || vapid_private_key.blank?

    recipient.push_subscriptions.find_each do |subscription|
      deliver(subscription, notification)
    end
  end

  private

  def deliver(subscription, notification)
    WebPush.payload_send(
      message: payload(notification).to_json,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh,
      auth: subscription.auth,
      vapid: {
        subject: ENV.fetch("VAPID_SUBJECT", "mailto:support@winewords.example"),
        public_key: vapid_public_key,
        private_key: vapid_private_key
      },
      ttl: 86_400
    )
    subscription.touch(:last_used_at)
  rescue WebPush::ResponseError => error
    code = error.response&.code.to_i
    subscription.destroy! if [ 404, 410 ].include?(code)
    raise unless [ 404, 410 ].include?(code)
  end

  def payload(notification)
    {
      title: "Wine Words",
      body: "You have a new Wine Words notification.",
      path: notification.target_path.presence ||
            (notification.wine_package_id ? "/wine-packages/#{notification.wine_package_id}" : "/notifications"),
      notification_id: notification.id
    }
  end

  def vapid_public_key
    ENV["VAPID_PUBLIC_KEY"]
  end

  def vapid_private_key
    ENV["VAPID_PRIVATE_KEY"]
  end
end
