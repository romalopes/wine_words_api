require "rails_helper"
require "devise"

# Issue #191: producer edit/delete rights are no longer "any linked user".
# Owners and managers may edit their own producer; contributors and unrelated
# users are read-only; only global Admins/Editors may delete.
RSpec.describe "Producer membership authorization", type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:australia) do
    Country.find_by(code: "AU") ||
      Country.create!(name: "Australia", code: "AU", continent: "Oceania", flag_emoji: "🇦🇺")
  end

  let!(:producer) { Producer.create!(name: "Estate #{SecureRandom.hex(4)}", email: "estate@example.com") }
  let!(:other_producer) { Producer.create!(name: "Rival #{SecureRandom.hex(4)}", email: "rival@example.com") }

  def create_user_with_role(role_name = nil)
    user = User.create!(email: "auth-#{SecureRandom.hex(4)}@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: role_name) if role_name
    user
  end

  def member_with(type, target: producer)
    user = create_user_with_role
    ProducerMembership.create!(user: user, producer: target, membership_type: type)
    user
  end

  def rename_payload
    { producer: { name: "Renamed #{SecureRandom.hex(3)}" } }
  end

  describe "PATCH /api/v1/producers/:id" do
    it "allows an owner to update their producer" do
      owner = member_with("owner")
      sign_in owner

      patch "/api/v1/producers/#{producer.slug}", params: rename_payload, as: :json

      expect(response).to have_http_status(:ok)
      expect(producer.reload.name).to start_with("Renamed")
    end

    it "allows a manager to update their producer" do
      manager = member_with("manager")
      sign_in manager

      patch "/api/v1/producers/#{producer.slug}", params: rename_payload, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "forbids a contributor from updating their producer" do
      contributor = member_with("contributor")
      sign_in contributor
      original_name = producer.name

      patch "/api/v1/producers/#{producer.slug}", params: rename_payload, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(producer.reload.name).to eq(original_name)
    end

    it "forbids a member of another producer" do
      outsider = member_with("owner", target: other_producer)
      sign_in outsider

      patch "/api/v1/producers/#{producer.slug}", params: rename_payload, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids an unrelated signed-in user" do
      sign_in create_user_with_role("Reader")

      patch "/api/v1/producers/#{producer.slug}", params: rename_payload, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "keeps the global Reviewer/Editor/Admin rights" do
      %w[Reviewer Editor Admin].each do |role|
        sign_in create_user_with_role(role)
        patch "/api/v1/producers/#{producer.slug}", params: rename_payload, as: :json
        expect(response).to have_http_status(:ok), "#{role} should keep producer-edit rights"
      end
    end

    it "returns unauthorized without authentication" do
      patch "/api/v1/producers/#{producer.slug}", params: rename_payload, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "logo endpoints" do
    it "forbids a contributor from uploading a logo" do
      contributor = member_with("contributor")
      sign_in contributor

      post "/api/v1/producers/#{producer.slug}/logo",
           params: { logo: Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/logo.png"), "image/png") }

      expect(response).to have_http_status(:forbidden)
      expect(producer.reload.logo).not_to be_attached
    end

    it "allows an owner to remove the logo" do
      producer.logo.attach(Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/logo.png"), "image/png"))
      owner = member_with("owner")
      sign_in owner

      delete "/api/v1/producers/#{producer.slug}/logo"

      expect(response).to have_http_status(:no_content)
      expect(producer.reload.logo).not_to be_attached
    end
  end
  describe "DELETE /api/v1/producers/:id" do
    it "forbids an owner from deleting their producer" do
      owner = member_with("owner")
      sign_in owner

      expect {
        delete "/api/v1/producers/#{producer.slug}"
      }.not_to change(Producer, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids reviewers from deleting producers" do
      sign_in create_user_with_role("Reviewer")

      expect {
        delete "/api/v1/producers/#{producer.slug}"
      }.not_to change(Producer, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "allows an admin to delete the producer" do
      sign_in create_user_with_role("Admin")

      expect {
        delete "/api/v1/producers/#{producer.slug}"
      }.to change(Producer, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "GET /api/v1/producers/:id (can_edit)" do
    it "is true for an owner and a manager" do
      %w[owner manager].each do |type|
        sign_in member_with(type)
        get "/api/v1/producers/#{producer.slug}"
        expect(JSON.parse(response.body)["can_edit"]).to be(true), "#{type} should be able to edit"
      end
    end

    it "is false for a contributor" do
      sign_in member_with("contributor")
      get "/api/v1/producers/#{producer.slug}"
      expect(JSON.parse(response.body)["can_edit"]).to be(false)
    end

    it "is false for the public" do
      get "/api/v1/producers/#{producer.slug}"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["can_edit"]).to be(false)
    end

    it "is true for catalogue staff" do
      sign_in create_user_with_role("Editor")
      get "/api/v1/producers/#{producer.slug}"
      expect(JSON.parse(response.body)["can_edit"]).to be(true)
    end
  end
end
