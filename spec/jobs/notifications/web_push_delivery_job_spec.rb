require "rails_helper"

RSpec.describe Notifications::WebPushDeliveryJob, type: :job do
  let(:user) do
    User.create!(first_name: "Push", email: "push-job-#{SecureRandom.hex(4)}@example.com",
                 password: "password123")
  end
  let(:notification) do
    Notification.create!(recipient: user, notification_type: "health_test",
                         message: "private text", delivered_at: Time.current)
  end

  it "sends a generic payload without the notification message" do
    NotificationPreference.for(user).update!(push_enabled: true)
    user.push_subscriptions.create!(endpoint: "https://push.example/one", p256dh: "key", auth: "auth")
    stub_const("ENV", ENV.to_h.merge("VAPID_PUBLIC_KEY" => "public", "VAPID_PRIVATE_KEY" => "private"))
    sent = nil
    allow(WebPush).to receive(:payload_send) { |args| sent = args }

    described_class.perform_now(notification.id)

    payload = JSON.parse(sent.fetch(:message))
    expect(payload.fetch("body")).to eq("You have a new Wine Words notification.")
    expect(payload.to_json).not_to include("private text")
  end
end
