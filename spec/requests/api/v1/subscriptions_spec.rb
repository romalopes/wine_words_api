require "rails_helper"
require "devise"

RSpec.describe "Api::V1::Subscriptions", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:super_user) do
    user = User.create!(name: "Super", email: "super@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Super User")
    user
  end

  let(:regular_user) do
    User.create!(name: "Regular", email: "regular@example.com", password: "password123")
  end

  before do
    # Ensure the test DB has subscription plans (idempotent seeds).
    load Rails.root.join("db/seeds/subscriptions.rb")
  end

  def subscription(name)
    Subscription.find_by!(name: name)
  end

  describe "GET /api/v1/subscriptions" do
    it "is public and returns only visible+active plans with features" do
      get "/api/v1/subscriptions"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.map { |s| s["name"] }).to contain_exactly("FREE", "Consumer", "Trade", "Distributor", "Retail")
      consumer = body.find { |s| s["name"] == "Consumer" }
      expect(consumer["popular"]).to eq(true)
      expect(consumer).to have_key("features")
      expect(consumer["yearly_price_cents"]).to eq(700)
    end

    it "hides inactive/hidden subscriptions from the public" do
      sub = subscription("Consumer")
      sub.update!(visible: false)
      get "/api/v1/subscriptions"
      body = JSON.parse(response.body)
      expect(body.map { |s| s["name"] }).not_to include("Consumer")
    end

    it "shows all subscriptions (incl. hidden) to a super user" do
      subscription("Consumer").update!(visible: false)
      sign_in super_user
      get "/api/v1/subscriptions"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).map { |s| s["name"] }).to include("Consumer")
    end
  end

  describe "creation / update (super user only)" do
    it "forbids non-super users from creating" do
      sign_in regular_user
      post "/api/v1/subscriptions", params: { subscription: { name: "Test", slug: "test" } }, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "allows a super user to create a plan with nested features" do
      sign_in super_user
      feature = SubscriptionFeature.find_by!(slug: "full-archive-access")
      post "/api/v1/subscriptions",
           params: { subscription: {
             name: "Premium", slug: "premium", yearly_price_cents: 100_00,
             subscription_subscription_features_attributes: [
               { subscription_feature_id: feature.id, position: 0 }
             ]
           } }, as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("Premium")
      expect(body["features"].map { |f| f["id"] }).to include(feature.id)
    end

    it "allows a super user to update a plan" do
      sign_in super_user
      patch "/api/v1/subscriptions/#{subscription('Consumer').id}",
            params: { subscription: { yearly_price_cents: 80_00 } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(subscription("Consumer").reload.yearly_price_cents).to eq(80_00)
    end
  end

  describe "DELETE /api/v1/subscriptions/:id" do
    it "refuses to destroy a plan with assigned users" do
      sign_in super_user
      consumer = subscription("Consumer")
      target = User.create!(name: "Target", email: "target@example.com", password: "password123")
      target.apply_subscription!(consumer)

      delete "/api/v1/subscriptions/#{consumer.id}"
      expect(response).to have_http_status(:unprocessable_entity)
      expect(Subscription.exists?(consumer.id)).to be true
    end

    it "destroys an unused plan" do
      sign_in super_user
      sub = Subscription.create!(name: "Junk", slug: "junk", yearly_price_cents: 50_00)
      delete "/api/v1/subscriptions/#{sub.id}"
      expect(response).to have_http_status(:no_content)
      expect(Subscription.exists?(sub.id)).to be false
    end
  end
end