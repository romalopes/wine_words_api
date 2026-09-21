require "rails_helper"

RSpec.describe "Api::V1::Users assign_roles self-lockout guard", type: :request do
  let(:admin_role) { Role.find_or_create_by!(name: "Admin") }
  let(:guest_role) { Role.find_or_create_by!(name: "Guest") }
  let(:admin) do
    User.create!(user_name: "Self Guard Admin", email: "self-guard-admin@example.com",
                 password: "password123", roles: [admin_role, guest_role])
  end

  before { sign_in admin }

  it "rejects an admin removing their own Admin role with 422" do
    guest_only = [guest_role.id]

    expect {
      patch "/api/v1/users/#{admin.id}/assign_roles",
            params: { role_ids: guest_only }, as: :json
    }.not_to change { admin.reload.roles.pluck(:name).sort }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["error"]).to include("cannot revoke your own Admin role")
  end

  it "still allows keeping Admin while changing other roles on self" do
    editor_role = Role.find_or_create_by!(name: "Editor")
    patch "/api/v1/users/#{admin.id}/assign_roles",
          params: { role_ids: [admin_role.id, editor_role.id] }, as: :json

    expect(response).to have_http_status(:ok)
    expect(admin.reload.role_names).to contain_exactly("Admin", "Editor")
  end

  it "still allows an admin to change another admin's roles" do
    other = User.create!(user_name: "Other Admin", email: "other-admin@example.com",
                         password: "password123", roles: [admin_role])
    patch "/api/v1/users/#{other.id}/assign_roles",
          params: { role_ids: [guest_role.id] }, as: :json

    expect(response).to have_http_status(:ok)
    expect(other.reload.role_names).to eq(["Guest"])
  end
end
