require "rails_helper"

RSpec.describe AccountInvitationAcceptance do
  it "allows exactly one concurrent acceptance of a single-use invitation" do
    user = User.create!(email: "race@example.com", account_status: :unclaimed)
    invitation, token = AccountInvitation.issue!(user:, email: user.email)

    results = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          described_class.accept!(
            raw_token: token,
            password: "race-password-123",
            password_confirmation: "race-password-123"
          )
          :accepted
        rescue described_class::Error => e
          e.code
        end
      end
    end.map(&:value)

    expect(results.count(:accepted)).to eq(1)
    expect(results.count("invalid_invitation")).to eq(1)
    expect(user.reload).to be_active
    expect(invitation.reload).to be_accepted
  end
end
