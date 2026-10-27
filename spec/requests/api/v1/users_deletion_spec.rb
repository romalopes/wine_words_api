require "rails_helper"

RSpec.describe "Api::V1::Users deletion", type: :request do
  include Devise::Test::IntegrationHelpers

  # Register the Stripe provider before validation (lazy autoloading).
  before { Billing::Providers::Stripe }

  let(:admin) { user_with_role("Admin") }
  let(:target) do
    User.create!(
      first_name: "Target",
      last_name: "User",
      email: "target-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
  end

  def user_with_role(role_name)
    user = User.create!(
      email: "#{role_name.downcase}-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
    user.roles << Role.find_or_create_by!(name: role_name)
    user
  end

  describe "DELETE /api/v1/users/:id/soft_delete" do
    it "soft deletes the user when called by an admin" do
      sign_in admin
      delete "/api/v1/users/#{target.id}/soft_delete"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["status"]).to eq("soft_deleted")
      expect(target.reload.deleted?).to be true
    end

    it "returns forbidden for non-admin users" do
      sign_in target
      delete "/api/v1/users/#{target.id}/soft_delete"
      expect(response).to have_http_status(:forbidden)
    end

    it "returns not found for a missing user" do
      sign_in admin
      delete "/api/v1/users/999999/soft_delete"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/users/:id/hard_delete" do
    context "when hard_delete_enabled is false (default)" do
      it "returns forbidden" do
        sign_in admin
        delete "/api/v1/users/#{target.id}/hard_delete"
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)["error"]).to eq("hard_delete_disabled")
      end
    end

    context "when hard_delete_enabled is true" do
      before do
        allow(AppSetting).to receive(:hard_delete_enabled?).and_return(true)
      end

      it "hard deletes the user when there are no blocking dependencies" do
        sign_in admin
        delete "/api/v1/users/#{target.id}/hard_delete"
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["status"]).to eq("hard_deleted")
        expect(User.find_by(id: target.id)).to be_nil
      end

      it "returns 409 when blocking dependencies exist" do
        BillingCustomer.create!(user: target, provider: "stripe", provider_customer_id: "cus_#{SecureRandom.hex(4)}")
        sign_in admin
        delete "/api/v1/users/#{target.id}/hard_delete"
        expect(response).to have_http_status(:conflict)
        expect(JSON.parse(response.body)["error"]).to eq("blocked")
        expect(User.find_by(id: target.id)).not_to be_nil
      end
    end
  end

  describe "POST /api/v1/users/:id/reactivate" do
    it "reactivates a soft-deleted user" do
      target.update!(deleted_at: Time.current)
      sign_in admin
      post "/api/v1/users/#{target.id}/reactivate"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["status"]).to eq("reactivated")
      expect(target.reload.deleted_at).to be_nil
    end

    it "returns forbidden for non-admin users" do
      sign_in target
      post "/api/v1/users/#{target.id}/reactivate"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/users/:id" do
    it "exposes deleted_at once the user has been soft-deleted" do
      sign_in admin
      AccountDeletionService.soft_delete(target, actor: admin)

      get "/api/v1/users/#{target.id}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["deleted_at"]).to be_present
    end
  end

  describe "server-side enforcement of deleted accounts" do
    it "rejects any authenticated request from a soft-deleted user" do
      sign_in target
      target.update!(deleted_at: Time.current)

      get "/api/v1/me"

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)["code"]).to eq("account_deleted")
    end
  end
end
