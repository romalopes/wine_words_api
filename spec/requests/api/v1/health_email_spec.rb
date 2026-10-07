# Request specs for the health e-mail tool (issue #167).
#
# This file pins down the two HTTP endpoints the React ApiHealth page drives:
#
#   GET  /api/v1/health/email/transport — public; reports the configured and
#     effective transports.
#   POST /api/v1/health/email/test      — admin-only; delivers one test e-mail
#     to the caller-supplied recipient and reports the outcome. Single-write
#     flow: nothing is persisted.
#
# The specs mirror the devise-jwt Bearer-token flow that the SPA uses for
# admin-only health diagnostics.
require "rails_helper"

RSpec.describe "Api::V1::Health e-mail tool", type: :request do
  include Devise::Test::IntegrationHelpers

  # --------------------------------------------------------------------------
  # Public transport report
  # --------------------------------------------------------------------------
  it "GET /api/v1/health/email/transport is public and reports both transports" do
    get "/api/v1/health/email/transport"

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body).to include("configured_transport")
    expect(body).to include("effective_transport")
    expect(body["configured_transport"]).to be_a(String)
    expect(body["effective_transport"]).to be_a(String)
  end

  # --------------------------------------------------------------------------
  # Admin-only delivery
  # --------------------------------------------------------------------------
  it "POST /api/v1/health/email/test is admin-only" do
    post "/api/v1/health/email/test"
    expect(response).to have_http_status(:unauthorized)

    user = User.create!(first_name: "Guest", email: "guest@example.com", password: "password123")
    sign_in user
    post "/api/v1/health/email/test"
    expect(response).to have_http_status(:forbidden)
  end

  it "POST /api/v1/health/email/test requires `to` and `content`" do
    admin = admin_user
    sign_in admin
    post "/api/v1/health/email/test", params: { content: "Body only" }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["error"]).to include("To")
  end

  it "POST /api/v1/health/email/test requires `content` when `to` is present" do
    admin = admin_user
    sign_in admin
    post "/api/v1/health/email/test", params: { to: "jane@doe.com" }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["error"]).to include("Content")
  end

  it "POST /api/v1/health/email/test delivers to the caller's recipient" do
    admin = admin_user
    sign_in admin

    expect do
      post "/api/v1/health/email/test",
           params: { to: "jane@doe.com", content: "The quick brown fox", subject: "Note" },
           as: :json
    end.to change(ActionMailer::Base.deliveries, :count).by(1)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body).to include("status" => "delivered")
    expect(body["recipients"]).to eq(["jane@doe.com"])
    expect(body["effective_transport"]).to eq("test")

    delivered = ActionMailer::Base.deliveries.last
    expect(delivered.to).to eq(["jane@doe.com"])
    expect(delivered.cc).to be_nil
    expect(delivered.bcc).to be_nil
    expect(delivered.subject).to eq("Note")
    expect(delivered.body.encoded).to include("Transport used: test")
    expect(delivered.body.encoded).to include("The quick brown fox")
  end

  it "POST /api/v1/health/email/test reports 500 when delivery fails" do
    admin = admin_user
    sign_in admin

    # The mailer's delivery (`do_delivery`) is the only thing that can fail;
    # the controller's `rescue` turns any delivery error into a JSON 500.
    allow(TestEmailMailer).to receive(:test_email)
      .and_raise(StandardError, "smtp connection refused")

    post "/api/v1/health/email/test",
         params: { to: "jane@doe.com", content: "Body" }, as: :json

    expect(response).to have_http_status(:internal_server_error)
    body = JSON.parse(response.body)
    expect(body["error"]).to include("Delivery failed")
    expect(body["code"]).to eq("email_delivery_failed")
  end

  # --------------------------------------------------------------------------
  # Helpers
  # --------------------------------------------------------------------------
  def admin_user
    admin = User.create!(first_name: "Admin", email: "admin@example.com", password: "password123")
    admin.roles << Role.find_or_create_by!(name: "Admin")
    admin
  end

  def admin_role
    @admin_role ||= Role.find_or_create_by!(name: "Admin")
  end

  def sign_in(user)
    post "/api/v1/auth/sign_in",
         params: { user: { email: user.email, password: "password123" } }, as: :json
    expect(response).to have_http_status(:ok)

    # The SPA authenticates with the JWT from the sign-in response.
    expect(response.headers["Authorization"]).to be_present
  end
end
