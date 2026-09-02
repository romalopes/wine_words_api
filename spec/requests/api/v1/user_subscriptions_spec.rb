require "rails_helper"
require "devise"

RSpec.describe "Api::V1::Users#assign_subscription", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:super_user) do
    user = User.create!(name: "Super", email: "super@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Super User")
    user
  end

  before do
    load Rails.root.join("db/seeds/subscriptions.rb")
  end

  def sub(name)
    Subscription.find_by!(name: name)
  end

  it "updates the user's subscription and swaps the base access role" do
    sign_in super_user
    user = User.create!(name: "John", email: "john@example.com", password: "password123")
    expect(user.reload.role_names).to include("Guest")

    patch "/api/v1/users/#{user.id}/assign_subscription",
          params: { subscription_id: sub("Consumer").id }, as: :json

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["subscription"]["name"]).to eq("Consumer")
    expect(body["roles"]).to include("Reader")
    expect(body["roles"]).not_to include("Guest")
  end

  it "preserves privileged roles when downgrading a user" do
    sign_in super_user
    user = User.create!(name: "Jane", email: "jane@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Reviewer")
    user.apply_subscription!(sub("Trade"))

    patch "/api/v1/users/#{user.id}/assign_subscription",
          params: { subscription_id: sub("FREE").id }, as: :json

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["roles"]).to include("Guest")
    expect(body["roles"]).to include("Reviewer")
    expect(body["roles"]).not_to include("Reader")
  end

  it "forbids non-super users from assigning subscriptions" do
    user = User.create!(name: "Regular", email: "rg@example.com", password: "password123")
    sign_in user
    patch "/api/v1/users/#{user.id}/assign_subscription",
          params: { subscription_id: sub("Consumer").id }, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "records subscription history" do
    sign_in super_user
    user = User.create!(name: "Hist", email: "hist@example.com", password: "password123")
    consumer = sub("Consumer")
    free = sub("FREE")

    patch "/api/v1/users/#{user.id}/assign_subscription", params: { subscription_id: consumer.id }, as: :json
    patch "/api/v1/users/#{user.id}/assign_subscription", params: { subscription_id: free.id }, as: :json

    histories = user.user_subscriptions.reload.order(:id)
    expect(histories.count).to eq(3) # default FREE + Consumer + FREE
    expect(histories.where(status: :active, ended_at: nil).first.subscription).to eq(free)
  end
end