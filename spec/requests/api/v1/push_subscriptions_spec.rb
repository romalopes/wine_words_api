require "rails_helper"

RSpec.describe "Api::V1::PushSubscriptions", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) do
    User.create!(first_name: "Push", email: "push-#{SecureRandom.hex(4)}@example.com",
                 password: "password123")
  end
  let(:payload) do
    { push_subscription: { endpoint: "https://push.example/#{SecureRandom.hex(4)}",
                           p256dh: "public-key", auth: "auth-secret" } }
  end

  it "requires authentication" do
    post "/api/v1/push_subscriptions", params: payload
    expect(response).to have_http_status(:unauthorized)
  end

  it "registers, lists, and removes only the current user's subscription" do
    sign_in user
    post "/api/v1/push_subscriptions", params: payload
    expect(response).to have_http_status(:created)
    id = JSON.parse(response.body).fetch("id")
    expect(NotificationPreference.for(user).push_enabled?).to be(true)

    get "/api/v1/push_subscriptions"
    expect(JSON.parse(response.body).map { |row| row.fetch("id") }).to eq([ id ])

    delete "/api/v1/push_subscriptions/#{id}"
    expect(response).to have_http_status(:no_content)
    expect(NotificationPreference.find_by!(user: user).push_enabled?).to be(false)
  end
end
