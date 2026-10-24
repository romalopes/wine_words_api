require "rails_helper"
require "devise"

# Covers the typed producer memberships added by issue #191: the three allowed
# types, the create/update payloads, server-derived actors, duplicate handling
# and the membership_type/can_edit fields the React app consumes.
RSpec.describe "Api::V1::ProducerMemberships", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create_admin_user }
  let(:editor) { create_user_with_role("Editor") }
  let(:reviewer) { create_user_with_role("Reviewer") }
  let(:reader) { create_user_with_role("Reader") }
  let(:user) { create_user_with_role("Reader") }
  let(:producer) { Producer.create!(name: "Test Producer #{SecureRandom.hex(4)}") }
  let(:membership) do
    ProducerMembership.create!(
      user: user, producer: producer, membership_type: "owner", created_by: admin
    )
  end

  def create_admin_user
    u = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123")
    u.roles << Role.find_or_create_by!(name: "Admin")
    u
  end

  def create_user_with_role(role_name)
    u = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com", password: "password123")
    u.roles << Role.find_or_create_by!(name: role_name)
    u
  end

  describe "GET /api/v1/users/:user_id/producer_memberships" do
    context "when admin" do
      it "returns the user's memberships with their type" do
        membership
        sign_in admin
        get "/api/v1/users/#{user.id}/producer_memberships"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json.first["id"]).to eq(membership.id)
        expect(json.first["membership_type"]).to eq("owner")
        expect(json.first["can_edit"]).to be(true)
      end
    end

    context "when editor (catalogue manager)" do
      it "returns the user's producer memberships" do
        membership
        sign_in editor
        get "/api/v1/users/#{user.id}/producer_memberships"

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).length).to eq(1)
      end
    end

    context "when reader" do
      it "returns forbidden" do
        sign_in reader
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
      sign_in admin

      get "/api/v1/producers/#{producer.id}/memberships"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to contain_exactly(include(
        "id" => membership.id,
        "membership_type" => "owner",
        "user" => include("id" => user.id, "email" => user.email),
        "producer" => include("id" => producer.id)
      ))
    end

    it "allows reviewers to view linked users" do
      membership
      sign_in reviewer

      get "/api/v1/producers/#{producer.id}/memberships"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).length).to eq(1)
    end

    it "forbids readers" do
      sign_in reader

      get "/api/v1/producers/#{producer.id}/memberships"

      expect(response).to have_http_status(:forbidden)
    end
  end
  describe "POST /api/v1/users/:user_id/producer_memberships" do
    let(:payload) do
      { producer_membership: { producer_id: producer.id, membership_type: "manager" } }
    end

    it "creates a typed membership for an admin" do
      sign_in admin
      expect {
        post "/api/v1/users/#{user.id}/producer_memberships", params: payload
      }.to change(ProducerMembership, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["producer"]["id"]).to eq(producer.id)
      expect(json["membership_type"]).to eq("manager")
      expect(json["can_edit"]).to be(true)
      expect(ProducerMembership.last.created_by).to eq(admin)
    end

    it "accepts the legacy flat payload (producer_id at the top level)" do
      sign_in admin
      post "/api/v1/users/#{user.id}/producer_memberships",
           params: { producer_id: producer.id, membership_type: "contributor" }

      expect(response).to have_http_status(:created)
      expect(ProducerMembership.last.membership_type).to eq("contributor")
    end

    it "ignores a client-supplied created_by_id" do
      sign_in editor
      post "/api/v1/users/#{user.id}/producer_memberships",
           params: { producer_membership: { producer_id: producer.id, membership_type: "owner",
                                            created_by_id: user.id } }

      expect(response).to have_http_status(:created)
      expect(ProducerMembership.last.created_by).to eq(editor)
    end

    it "rejects a missing membership_type" do
      sign_in admin
      post "/api/v1/users/#{user.id}/producer_memberships",
           params: { producer_membership: { producer_id: producer.id } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to include("Membership type can't be blank")
      expect(ProducerMembership.count).to eq(0)
    end

    it "rejects follower and viewer values" do
      sign_in admin
      %w[follower viewer].each do |type|
        post "/api/v1/users/#{user.id}/producer_memberships",
             params: { producer_membership: { producer_id: producer.id, membership_type: type } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["errors"])
          .to include("Membership type must be owner, manager, or contributor")
      end
      expect(ProducerMembership.count).to eq(0)
    end

    it "rejects a missing producer_id" do
      sign_in admin
      post "/api/v1/users/#{user.id}/producer_memberships",
           params: { producer_membership: { membership_type: "manager" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to include("Producer can't be blank")
      expect(ProducerMembership.count).to eq(0)
    end

    it "returns conflict for a duplicate membership" do
      membership
      sign_in admin
      post "/api/v1/users/#{user.id}/producer_memberships", params: payload

      expect(response).to have_http_status(:conflict)
      expect(ProducerMembership.count).to eq(1)
    end

    it "returns forbidden for a reader" do
      sign_in reader
      post "/api/v1/users/#{user.id}/producer_memberships", params: payload
      expect(response).to have_http_status(:forbidden)
    end

    it "returns unauthorized without authentication" do
      post "/api/v1/users/#{user.id}/producer_memberships", params: payload
      expect(response).to have_http_status(:unauthorized)
    end
  end
  describe "PATCH /api/v1/users/:user_id/producer_memberships/:id" do
    it "changes the membership type" do
      membership
      sign_in admin

      patch "/api/v1/users/#{user.id}/producer_memberships/#{membership.id}",
            params: { producer_membership: { membership_type: "contributor" } }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["membership_type"]).to eq("contributor")
      expect(membership.reload.membership_type).to eq("contributor")
    end

    it "lets editors change the membership type" do
      membership
      sign_in editor

      patch "/api/v1/users/#{user.id}/producer_memberships/#{membership.id}",
            params: { producer_membership: { membership_type: "manager" } }

      expect(response).to have_http_status(:ok)
      expect(membership.reload.membership_type).to eq("manager")
    end

    it "rejects an unknown type without changing the record" do
      membership
      sign_in admin

      patch "/api/v1/users/#{user.id}/producer_memberships/#{membership.id}",
            params: { producer_membership: { membership_type: "follower" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(membership.reload.membership_type).to eq("owner")
    end

    it "rejects a blank type" do
      membership
      sign_in admin

      patch "/api/v1/users/#{user.id}/producer_memberships/#{membership.id}",
            params: { producer_membership: { membership_type: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(membership.reload.membership_type).to eq("owner")
    end

    it "does not let a membership be edited through another user's path" do
      membership
      other_user = create_user_with_role("Reader")
      sign_in admin

      patch "/api/v1/users/#{other_user.id}/producer_memberships/#{membership.id}",
            params: { producer_membership: { membership_type: "manager" } }

      expect(response).to have_http_status(:not_found)
      expect(membership.reload.membership_type).to eq("owner")
    end

    it "returns forbidden for a reader" do
      membership
      sign_in reader

      patch "/api/v1/users/#{user.id}/producer_memberships/#{membership.id}",
            params: { producer_membership: { membership_type: "manager" } }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/users/:user_id/producer_memberships/:id" do
    it "removes the membership as an admin" do
      membership
      sign_in admin
      expect {
        delete "/api/v1/users/#{user.id}/producer_memberships/#{membership.id}"
      }.to change(ProducerMembership, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "removes the membership as an editor" do
      membership
      sign_in editor
      expect {
        delete "/api/v1/users/#{user.id}/producer_memberships/#{membership.id}"
      }.to change(ProducerMembership, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "returns forbidden for a reader" do
      membership
      sign_in reader
      delete "/api/v1/users/#{user.id}/producer_memberships/#{membership.id}"
      expect(response).to have_http_status(:forbidden)
    end
  end
  describe "GET /api/v1/users/:id" do
    it "returns user detail with typed memberships for an admin" do
      membership
      sign_in admin

      get "/api/v1/users/#{user.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(user.id)
      expect(json["producer_memberships"].length).to eq(1)
      expect(json["producer_memberships"].first["membership_type"]).to eq("owner")
    end

    it "returns user detail with memberships for an editor" do
      membership
      sign_in editor

      get "/api/v1/users/#{user.id}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["producer_memberships"].length).to eq(1)
    end

    it "returns forbidden for a reader" do
      sign_in reader
      get "/api/v1/users/#{user.id}"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/account/producers" do
    it "returns the membership type and edit capability for owners" do
      membership
      sign_in user

      get "/api/v1/account/producers"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first).to include(
        "id" => producer.id,
        "membership_id" => membership.id,
        "membership_type" => "owner",
        "can_edit" => true
      )
    end

    it "marks contributors as read-only" do
      ProducerMembership.create!(
        user: user, producer: producer, membership_type: "contributor", created_by: admin
      )
      sign_in user

      get "/api/v1/account/producers"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.first["membership_type"]).to eq("contributor")
      expect(json.first["can_edit"]).to be(false)
    end

    it "returns an empty array when the user has no memberships" do
      sign_in user
      get "/api/v1/account/producers"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end
  end
end
