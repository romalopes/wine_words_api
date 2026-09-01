require "rails_helper"

RSpec.describe "Wine update flow", type: :request do
  let(:user) { User.create!(email: "spec@example.com", password: "password123", password_confirmation: "password123") }
  let!(:producer) { Producer.create!(name: "Spec Producer #{rand(100000)}", email: "spec#{rand(100000)}@example.com") }
  let!(:wine) { producer.wines.create!(name: "Spec Wine #{rand(100000)}", color: "Red") }

  before do
    user.roles << Role.find_or_create_by!(name: "Editor")
    post "/login", params: { email: user.email, password: "password123" }
  end

  it "updates a wine via its slug URL" do
    get edit_wine_path(wine.slug)
    expect(response).to have_http_status(:ok)

    patch wine_path(wine.slug), params: { wine: { color: "White" } }
    expect(response).to redirect_to(wine_path(wine.slug))
    expect(wine.reload.color).to eq("White")
  end

  it "updates a producer via its slug URL" do
    producer = wine.producer || Producer.create!(name: "Test Producer #{rand(1000)}")
    patch producer_path(producer.slug), params: { producer: { name: producer.name } }
    expect(response).to redirect_to(producer_path(producer.slug))
  end
end
