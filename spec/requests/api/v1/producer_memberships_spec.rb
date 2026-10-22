require "rails_helper"
require "devise"

RSpec.describe "Api::V1::ProducerMemberships", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create_admin_user }
  let(:editor) { create_user_with_role("Editor") }
  let(:reviewer) { create_user_with_role("Reviewer") }
  let(:reader) { create_user_with_role("Reader") }
  let(:user) { create_user_with_role("Reader") }
  let(:producer) { Producer.create!(name: "Test Producer", slug: "test-producer") }
  let(:membership) { ProducerMembership.create!(user: user, producer: producer, created_by: admin) }

  def create_admin_user
    u = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123")
    admin_role = Role.find_or_create_by!(name: "Admin")
    u.roles << admin_role
    u
  end

  def create_user_with_role(role_name)
    u = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com", password: "password123")
    role = Role.find_or_create_by!(name: role_name)
    u.roles << role
    u
  end

  def sign_in_as(user)
    sign_in user
  end

  describe "GET /api/v1/users/:user_id/producer_memberships" do
    context "when admin" do
      it "returns the user's producer memberships" do
        membership # create it
        sign_in_as(admin)
        get "/api/v1/users/#{user.id}/producer_memberships"
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json.first["id"]).to eq(membership.id)
      end
    end

    context "when editor (catalogue manager)" do
      it "returns the user's producer memberships" do
        membership # create it
        sign_in_as(editor)
        get "/api/v1/users/#{user.id}/producer_memberships"
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json.first["id"]).to eq(membership.id)
      end
    end

    context "when reader" do
      it "returns forbidden" do
        sign_in_as(reader)
        get "/api/v1/users/#{user.id}/producer_memberships"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns unauthorized" do
        get "/api/v1/users/#{user.id}/producer_memberships"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/producers/:id/memberships" do
    it "returns users linked to the producer for an admin" do
      membership
      sign_in_as(admin)

      get "/api/v1/producers/#{producer.id}/memberships"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to contain_exactly(include(
        "id" => membership.id,
        "user" => include("id" => user.id, "email" => user.email),
        "producer" => include("id" => producer.id)
      ))
    end

    it "allows reviewers to view linked users" do
      membership
      sign_in_as(reviewer)

      get "/api/v1/producers/#{producer.id}/memberships"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).length).to eq(1)
    end

    it "forbids readers" do
      sign_in_as(reader)

      get "/api/v1/producers/#{producer.id}/memberships"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/users/:user_id/producer_memberships" do
    context "when admin" do
      it "creates a new membership" do
        sign_in_as(admin)
        expect {
          post "/api/v1/users/#{user.id}/producer_memberships",
               params: { producer_id: producer.id }
        }.to change(ProducerMembership, :count).by(1)
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["producer"]["id"]).to eq(producer.id)
      end

      it "returns error for duplicate membership" do
        membership # create it
        sign_in_as(admin)
        post "/api/v1/users/#{user.id}/producer_memberships",
             params: { producer_id: producer.id }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when editor (catalogue manager)" do
      it "creates a new membership" do
        sign_in_as(editor)
        expect {
          post "/api/v1/users/#{user.id}/producer_memberships",
               params: { producer_id: producer.id }
        }.to change(ProducerMembership, :count).by(1)
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["producer"]["id"]).to eq(producer.id)
      end
    end

    context "when reader" do
      it "returns forbidden" do
        sign_in_as(reader)
        post "/api/v1/users/#{user.id}/producer_memberships",
             params: { producer_id: producer.id }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /api/v1/users/:user_id/producer_memberships/:id" do
    context "when admin" do
      it "removes the membership" do
        membership # create it
        sign_in_as(admin)
        expect {
          delete "/api/v1/users/#{user.id}/producer_memberships/#{membership.id}"
        }.to change(ProducerMembership, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when editor (catalogue manager)" do
      it "removes the membership" do
        membership # create it
        sign_in_as(editor)
        expect {
          delete "/api/v1/users/#{user.id}/producer_memberships/#{membership.id}"
        }.to change(ProducerMembership, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when reader" do
      it "returns forbidden" do
        membership # create it
        sign_in_as(reader)
        delete "/api/v1/users/#{user.id}/producer_memberships/#{membership.id}"
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/v1/users/:id" do
    context "when admin" do
      it "returns user detail with memberships" do
        membership # create it
        sign_in_as(admin)
        get "/api/v1/users/#{user.id}"
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(user.id)
        expect(json["producer_memberships"].length).to eq(1)
      end
    end

    context "when editor (catalogue manager)" do
      it "returns user detail with memberships" do
        membership # create it
        sign_in_as(editor)
        get "/api/v1/users/#{user.id}"
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(user.id)
        expect(json["producer_memberships"].length).to eq(1)
      end
    end

    context "when reader" do
      it "returns forbidden" do
        sign_in_as(reader)
        get "/api/v1/users/#{user.id}"
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/v1/account/producers" do
    context "when authenticated user has memberships" do
      let(:user_with_membership) do
        u = create_user_with_role("Reader")
        ProducerMembership.create!(user: u, producer: producer, created_by: admin)
        u
      end

      it "returns the user's linked producers" do
        sign_in_as(user_with_membership)
        get "/api/v1/account/producers"
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json.first["id"]).to eq(producer.id)
      end
    end

    context "when user has no memberships" do
      it "returns empty array" do
        sign_in_as(user)
        get "/api/v1/account/producers"
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to eq([])
      end
    end
  end
end