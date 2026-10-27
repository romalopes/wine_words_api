require "rails_helper"

RSpec.describe AccountInvitationsMailer, type: :mailer do
  it "uses configured frontend URL, expiry, recipient, and no password" do
    user = User.create!(first_name: "Mail", last_name: "Recipient", email: "mail@example.com", account_status: :unclaimed)
    invitation, token = AccountInvitation.issue!(user:, email: user.email)

    previous_frontend_url = ENV["FRONTEND_URL"]
    ENV["FRONTEND_URL"] = "https://wine.example"
    begin
      mail = described_class.invitation(invitation, token)
      text_body = mail.text_part.decoded

      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to eq("You're invited to Wine Words")
      expect(text_body).to include("https://wine.example/accept-invitation#token=#{token}")
      expect(text_body).to include(invitation.expires_at.year.to_s)
      expect(text_body.downcase).not_to include("temporary password")
    ensure
      ENV["FRONTEND_URL"] = previous_frontend_url
    end
  end
end
