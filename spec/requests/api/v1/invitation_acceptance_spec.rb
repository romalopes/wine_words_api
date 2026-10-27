require "rails_helper"

RSpec.describe "Public invitation acceptance", type: :request do
  let(:user) do
    User.create!(first_name: "Invitation", last_name: "Recipient", email: "recipient@example.com", account_status: :unclaimed)
  end

  def issue
    AccountInvitation.issue!(user:, email: user.email)
  end

  it "validates using POST and returns only safe invitation context" do
    invitation, token = issue
    post "/api/v1/invitations/validate", params: { token: }, as: :json

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include(
      "valid" => true,
      "invitation" => include("email" => "r********@example.com", "display_name" => "Invitation Recipient")
    )
    expect(response.body).not_to include(token, invitation.token_digest, user.email)
  end

  it "accepts atomically, activates the user, and does not issue a JWT" do
    invitation, token = issue
    post "/api/v1/invitations/accept",
         params: { token:, password: "new-password-123", password_confirmation: "new-password-123" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.headers["Authorization"]).to be_blank
    expect(user.reload).to be_active
    expect(user.valid_password?("new-password-123")).to be true
    expect(user.email_verified_at).to be_present
    expect(invitation.reload).to be_accepted
  end

  it "rejects replay, expiry, revocation, and changed email generically" do
    cases = []
    invitation, token = issue
    invitation.update!(status: :accepted, accepted_at: Time.current)
    cases << token

    invitation, token = issue
    invitation.update!(expires_at: 1.second.ago)
    cases << token

    invitation, token = issue
    invitation.revoke!
    cases << token

    invitation, token = issue
    user.update_column(:email, "changed@example.com")
    cases << token

    cases.each do |invalid_token|
      post "/api/v1/invitations/validate", params: { token: invalid_token }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body).fetch("code")).to eq("invalid_invitation")
    end
  end

  it "rejects password validation errors without consuming the invitation" do
    invitation, token = issue
    post "/api/v1/invitations/accept",
         params: { token:, password: "short", password_confirmation: "different" }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body).fetch("code")).to eq("validation_failed")
    expect(invitation.reload).to be_usable
    expect(user.reload).to be_unclaimed
  end
end
