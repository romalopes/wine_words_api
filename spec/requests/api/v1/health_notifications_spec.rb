# Request specs for the health notification tool.
#
# Mirrors the health e-mail tool specs: this file pins down the single HTTP
# endpoint the React ApiHealth page drives:
#
#   POST /api/v1/health/notifications/test — admin-only; delivers one in-app
#     notification to the signed-in admin and reports the same unread count the
#     notification bell will display, so "the new notification is reflected in
#     the bell" is verified against the real bell data source
#     (GET /api/v1/notifications/unread_count).
require "rails_helper"

RSpec.describe "Api::V1::Health notification tool", type: :request do
  include Devise::Test::IntegrationHelpers

  # --------------------------------------------------------------------------
  # Authorization
  # --------------------------------------------------------------------------
  it "POST /api/v1/health/notifications/test requires a signed-in user" do
    post "/api/v1/health/notifications/test"
    expect(response).to have_http_status(:unauthorized)
  end

  it "POST /api/v1/health/notifications/test is admin-only" do
    user = User.create!(first_name: "Guest", email: "guest@example.com", password: "password123")
    sign_in user
    post "/api/v1/health/notifications/test"
    expect(response).to have_http_status(:forbidden)
  end

  # --------------------------------------------------------------------------
  # Delivery + bell reflection
  # --------------------------------------------------------------------------
  it "delivers a health_test notification to the signed-in admin and reports the bell's unread count" do
    admin = admin_user
    sign_in admin

    expect do
      post "/api/v1/health/notifications/test", as: :json
    end.to change(Notification.where(notification_type: "health_test"), :count).by(1)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("delivered")
    expect(body["notification_type"]).to eq("health_test")
    expect(body["message"]).to be_present
    expect(body["delivered_at"]).to be_present

    notification = Notification.find(body["notification_id"])
    expect(notification.recipient).to eq(admin)
    expect(notification).to be_delivered
    expect(notification).not_to be_read

    # The number the bell will show must include the new notification.
    expect(body["unread_count"]).to be >= 1
    expect(body["unread_count"]).to eq(
      admin.notifications.delivered.unread.count
    )
  end

  it "is visible through the bell's data source and the notifications feed" do
    admin = admin_user
    sign_in admin

    post "/api/v1/health/notifications/test", as: :json
    expect(response).to have_http_status(:ok)
    notification_id = JSON.parse(response.body)["notification_id"]

    # The bell's badge endpoint (what /admin/api-health verifies) must count it.
    get "/api/v1/notifications/unread_count"
    expect(JSON.parse(response.body)["unread_count"]).to be >= 1

    # The in-app feed must list it as a delivered row.
    get "/api/v1/notifications"
    feed = JSON.parse(response.body)
    items = feed.is_a?(Array) ? feed : feed.dig("items") || feed.dig("notifications") || []
    expect(items.map { |item| item["id"] }).to include(notification_id)
    expect(items.map { |item| item["notification_type"] }).to include("health_test")
  end

  it "re-runs are idempotent: today's test row is re-marked unread, not duplicated" do
    admin = admin_user
    sign_in admin

    post "/api/v1/health/notifications/test", as: :json
    first_id = JSON.parse(response.body)["notification_id"]

    post "/api/v1/health/notifications/test", as: :json
    expect(response).to have_http_status(:ok)

    body = JSON.parse(response.body)
    expect(body["notification_id"]).to eq(first_id)
    expect(Notification.where(notification_type: "health_test").count).to eq(1)
    expect(body["unread_count"]).to be >= 1
  end

  it "re-marks a previously read test notification as unread so the bell reflects it again" do
    admin = admin_user
    sign_in admin

    post "/api/v1/health/notifications/test", as: :json
    notification = Notification.find(JSON.parse(response.body)["notification_id"])
    notification.mark_read!

    get "/api/v1/notifications/unread_count"
    count_after_read = JSON.parse(response.body)["unread_count"]

    post "/api/v1/health/notifications/test", as: :json
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["unread_count"]).to be > count_after_read
    expect(notification.reload).not_to be_read
  end

  it "reports 500 when persistence fails" do
    admin = admin_user
    sign_in admin
    allow(Notification).to receive(:notify!)
      .and_raise(StandardError, "database unavailable")

    post "/api/v1/health/notifications/test", as: :json
    expect(response).to have_http_status(:internal_server_error)
    body = JSON.parse(response.body)
    expect(body["error"]).to include("Notification test failed")
    expect(body["code"]).to eq("notification_test_failed")
  end

  # --------------------------------------------------------------------------
  # Helpers
  # --------------------------------------------------------------------------
  def admin_user
    admin = User.create!(first_name: "Health Admin", email: "health-admin@example.com", password: "password123")
    admin.roles << Role.find_or_create_by!(name: "Admin")
    admin
  end

  def sign_in(user)
    post "/api/v1/auth/sign_in",
         params: { user: { email: user.email, password: "password123" } },
         as: :json

    # The SPA authenticates with the JWT from the sign-in response.
    expect(response.headers["Authorization"]).to be_present
  end
end
