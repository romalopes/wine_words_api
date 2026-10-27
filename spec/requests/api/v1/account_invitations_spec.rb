require "rails_helper"

RSpec.describe "Account invitation management", type: :request do
  def user_with_role(role_name)
    User.create!(
      email: "#{role_name.downcase}-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      roles: [ Role.find_or_create_by!(name: role_name) ]
    )
  end

  let(:admin) { user_with_role("Admin") }
  let(:editor) { user_with_role("Editor") }
  let(:reader) { user_with_role("Reader") }
  let(:invitee) do
    User.create!(first_name: "Invited", last_name: "Person", email: "invited@example.com", account_status: :unclaimed)
  end

  before { ActionMailer::Base.deliveries.clear }

  it "allows admins and editors to send and list invitations without exposing tokens" do
    [ admin, editor ].each do |actor|
      sign_in actor
      expect {
        post "/api/v1/users/#{invitee.id}/invitations", as: :json
      }.to change(ActionMailer::Base.deliveries, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.body).not_to include("token")
      expect(JSON.parse(response.body)).to include("status" => "sent", "delivery_status" => "accepted")

      get "/api/v1/users/#{invitee.id}/invitations", as: :json
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("token_digest")

      invitee.account_invitations.order(:created_at).last.update!(last_delivery_attempt_at: 2.minutes.ago)
      sign_out actor
    end
  end

  it "rejects readers and accounts without email" do
    sign_in reader
    post "/api/v1/users/#{invitee.id}/invitations", as: :json
    expect(response).to have_http_status(:forbidden)

    sign_out reader
    no_email = User.create!(first_name: "No", last_name: "Email", account_status: :unclaimed)
    sign_in admin
    post "/api/v1/users/#{no_email.id}/invitations", as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body).fetch("code")).to eq("email_required")
  end

  it "prevents editors from managing invitations for privileged targets" do
    privileged = User.create!(email: "privileged@example.com", account_status: :unclaimed,
                              roles: [ Role.find_or_create_by!(name: "Editor") ])
    sign_in editor

    get "/api/v1/users/#{privileged.id}/invitations", as: :json
    expect(response).to have_http_status(:forbidden)
    post "/api/v1/users/#{privileged.id}/invitations", as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "rejects active, suspended, and deleted targets" do
    targets = [
      User.create!(email: "active@example.com", password: "password123"),
      User.create!(email: "suspended@example.com", password: "password123", account_status: :suspended),
      User.create!(email: "deleted@example.com", account_status: :unclaimed, deleted_at: Time.current)
    ]
    sign_in admin

    targets.each do |target|
      post "/api/v1/users/#{target.id}/invitations", as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  it "rate limits repeated sends and lets revoke preserve history" do
    sign_in admin
    post "/api/v1/users/#{invitee.id}/invitations", as: :json
    first = invitee.account_invitations.sole

    post "/api/v1/users/#{invitee.id}/invitations/resend", as: :json
    expect(response).to have_http_status(:too_many_requests)
    expect(invitee.account_invitations.count).to eq(1)

    first.update!(last_delivery_attempt_at: 2.minutes.ago)
    post "/api/v1/users/#{invitee.id}/invitations/resend", as: :json
    expect(response).to have_http_status(:created)
    expect(first.reload).to be_revoked
    expect(invitee.account_invitations.count).to eq(2)

    post "/api/v1/users/#{invitee.id}/invitations/revoke", as: :json
    expect(response).to have_http_status(:ok)
    expect(invitee.account_invitations.order(:created_at).last.reload).to be_revoked
  end

  it "records a retryable delivery failure without returning the raw token" do
    sign_in admin
    allow(AccountInvitationsMailer).to receive(:invitation).and_raise(Net::OpenTimeout)

    post "/api/v1/users/#{invitee.id}/invitations", as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body).fetch("code")).to eq("invitation_delivery_failed")
    expect(response.body).not_to include("token")
    expect(invitee.account_invitations.sole).to have_attributes(delivery_status: "failed", delivery_error_code: "Net::OpenTimeout")
  end
end
