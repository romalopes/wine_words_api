require "rails_helper"
require "devise"

RSpec.describe "Api::V1::Users#assign_subscription", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    user = User.create!(user_name: "Admin", email: "admin@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end

  before do
    load Rails.root.join("db/seeds/subscriptions.rb")
  end

  def sub(name)
    Subscription.find_by!(name: name)
  end

  it "updates the user's subscription and swaps the base access role" do
    sign_in admin
    user = User.create!(user_name: "John", email: "john@example.com", password: "password123")
    expect(user.reload.role_names).to include("Guest")

    patch "/api/v1/users/#{user.id}/assign_subscription",
          params: { subscription_id: sub("Consumer").id }, as: :json

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["subscription"]["name"]).to eq("Consumer")
    expect(body["roles"]).to include("Reader")
    expect(body["roles"]).not_to include("Guest")
  end

  it "rejects downgrading a user to a lower-priced plan" do
    sign_in admin
    user = User.create!(user_name: "Jane", email: "jane@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Reviewer")
    user.apply_subscription!(sub("Trade"))

    patch "/api/v1/users/#{user.id}/assign_subscription",
          params: { subscription_id: sub("FREE").id }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    body = JSON.parse(response.body)
    expect(body["error"]).to match(/downgrade/i)
    expect(user.reload.subscription).to eq(sub("Trade"))
    expect(user.role_names).to include("Reader")
    expect(user.role_names).to include("Reviewer")
  end

  it "rejects downgrading a user to a lower-priced paid plan" do
    sign_in admin
    user = User.create!(user_name: "Bob", email: "bob@example.com", password: "password123")
    user.apply_subscription!(sub("Trade"))

    patch "/api/v1/users/#{user.id}/assign_subscription",
          params: { subscription_id: sub("Consumer").id }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    body = JSON.parse(response.body)
    expect(body["error"]).to match(/downgrade/i)
    expect(user.reload.subscription).to eq(sub("Trade"))
  end

  it "allows upgrading a user to a higher-priced plan" do
    sign_in admin
    user = User.create!(user_name: "Alice", email: "alice@example.com", password: "password123")
    user.apply_subscription!(sub("Consumer"))

    patch "/api/v1/users/#{user.id}/assign_subscription",
          params: { subscription_id: sub("Trade").id }, as: :json

    expect(response).to have_http_status(:ok)
    expect(user.reload.subscription).to eq(sub("Trade"))
  end

  it "forbids non-admins from assigning subscriptions" do
    user = User.create!(user_name: "Regular", email: "rg@example.com", password: "password123")
    sign_in user
    patch "/api/v1/users/#{user.id}/assign_subscription",
          params: { subscription_id: sub("Consumer").id }, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "records subscription history for upgrades" do
    sign_in admin
    user = User.create!(user_name: "Hist", email: "hist@example.com", password: "password123")
    consumer = sub("Consumer")
    trade = sub("Trade")

    patch "/api/v1/users/#{user.id}/assign_subscription", params: { subscription_id: consumer.id }, as: :json
    patch "/api/v1/users/#{user.id}/assign_subscription", params: { subscription_id: trade.id }, as: :json

    histories = user.user_subscriptions.reload.order(:id)
    expect(histories.count).to eq(3)
    expect(histories.where(status: :active, ended_at: nil).first.subscription).to eq(trade)
  end
end
