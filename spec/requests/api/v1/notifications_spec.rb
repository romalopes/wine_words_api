require "rails_helper"

# Request specs for Api::V1::NotificationsController — a user's own deadline
# reminders. Reminders are created by the scheduling service, so the specs seed
# them with Notification.notify! exactly as the service does.
RSpec.describe "Api::V1::Notifications", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:producer) { Producer.create!(name: "Penfolds") }
  let(:user) do
    u = User.create!(user_name: "Notif User", email: "notif-user@example.com", password: "password123")
    u.roles << Role.find_or_create_by!(name: "Admin")
    u
  end
  let(:other_user) { User.create!(user_name: "Notif Other", email: "notif-other@example.com", password: "password123") }
  let(:package) do
    WinePackage.create!(producer: producer, reviewer: user, created_by: user,
                        source: "unexpected", status: "arrived",
                        arrived_at: Time.current, review_deadline: Date.current + 20)
  end
  let(:other_package) do
    WinePackage.create!(producer: producer, reviewer: other_user, created_by: other_user,
                        source: "unexpected", status: "arrived",
                        arrived_at: Time.current, review_deadline: Date.current + 20)
  end

  # Mirrors how WinePackages::Notifications::Schedule creates reminders: the
  # dedup key is (package, type, scheduled_date), so a package can only hold one
  # reminder per day. Rows start undelivered exactly as the scheduler leaves
  # them; pass `sent: true` for a reminder the delivery job has already sent.
  def notify(recipient:, on_package: nil, date: Date.current,
             message: "Deadline approaching", sent: false)
    pkg = on_package || package
    reminder = Notification.notify!(recipient: recipient, type: "wine_package_deadline",
                                    notifiable: pkg, wine_package: pkg,
                                    scheduled_date: date, message: message)
    reminder.update!(sent_at: Time.current) if sent
    reminder
  end

  before { sign_in user }

  describe "GET /api/v1/notifications" do
    it "returns only the signed-in user's notifications" do
      notify(recipient: user, sent: true)
      notify(recipient: other_user, on_package: other_package, sent: true)

      get "/api/v1/notifications"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(1)
      expect(body.first).to include(
        "notification_type" => "wine_package_deadline",
        "producer_name" => "Penfolds",
        "package_status" => "arrived",
        "sent" => true,
        "read" => false
      )
      expect(body.first["wine_package_id"]).to eq(package.id)
    end

    it "hides reminders that have not been delivered yet" do
      # The scheduler pre-creates the 15/5/0-day reminders as soon as a package
      # arrives; they only become visible once the daily job has sent them.
      notify(recipient: user, date: Date.current + 15, message: "Queued for later")
      notify(recipient: user, date: Date.current, message: "Delivered today", sent: true)

      get "/api/v1/notifications"

      body = JSON.parse(response.body)
      expect(body.length).to eq(1)
      expect(body.first["message"]).to eq("Delivered today")
    end

    it "keeps one reminder per package and day, whoever asks" do
      first = notify(recipient: user)
      # Same package, same day: the reminder is reused, not duplicated.
      again = notify(recipient: other_user)

      expect(again.id).to eq(first.id)
      expect(Notification.where(wine_package: package).count).to eq(1)
    end

    it "filters unread notifications and paginates" do
      read_one = notify(recipient: user, sent: true)
      read_one.mark_read!
      notify(recipient: user, date: Date.current + 1, message: "Still unread", sent: true)

      get "/api/v1/notifications", params: { unread: "true", page: 1, per_page: 1 }

      body = JSON.parse(response.body)
      expect(body["total_count"]).to eq(1)
      expect(body["items"].length).to eq(1)
      expect(body["items"].first["read"]).to be false
    end

    it "filters by scheduled date" do
      notify(recipient: user, date: Date.current + 5, sent: true)
      get "/api/v1/notifications", params: { date: (Date.current + 5).iso8601 }

      expect(JSON.parse(response.body).length).to eq(1)
    end

    it "requires authentication" do
      sign_out user
      get "/api/v1/notifications"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/notifications/:id/mark_read" do
    it "marks the notification read" do
      notification = notify(recipient: user, sent: true)

      patch "/api/v1/notifications/#{notification.id}/mark_read"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["read"]).to be true
      expect(notification.reload.read_at).to be_present
    end

    it "cannot touch a reminder that has not been delivered yet" do
      queued = notify(recipient: user, date: Date.current + 5, message: "Queued")

      patch "/api/v1/notifications/#{queued.id}/mark_read"

      expect(response).to have_http_status(:not_found)
      expect(queued.reload.read_at).to be_nil
    end

    it "cannot touch another user's notification" do
      notification = notify(recipient: other_user, sent: true)

      patch "/api/v1/notifications/#{notification.id}/mark_read"

      expect(response).to have_http_status(:not_found)
      expect(notification.reload.read_at).to be_nil
    end
  end

  describe "PATCH /api/v1/notifications/mark_all_read" do
    it "marks every delivered unread notification of the signed-in user only" do
      first = notify(recipient: user, sent: true)
      # A reminder still queued for future delivery stays unread: the user has
      # not received it yet, so it must surface as unread on its due date.
      queued = notify(recipient: user, date: Date.current + 1, message: "Queued")
      theirs = notify(recipient: other_user, on_package: other_package, sent: true)

      patch "/api/v1/notifications/mark_all_read"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["marked"]).to eq(1)
      expect(first.reload.read_at).to be_present
      expect(queued.reload.read_at).to be_nil
      expect(theirs.reload.read_at).to be_nil
    end
  end
end
