require "rails_helper"

RSpec.describe AccountInvitation, type: :model do
  def create_user(email: "invitee@example.com", status: :unclaimed)
    attributes = { email: email, account_status: status }
    attributes[:password] = "password123" unless status == :unclaimed
    User.create!(attributes)
  end

  let(:user) { create_user }
  let(:actor) do
    User.create!(email: "admin@example.com", password: "password123")
  end

  describe ".issue!" do
    it "stores only a SHA-256 digest of a high-entropy token" do
      invitation, raw_token = described_class.issue!(user: user, email: " INVITEE@example.com ", invited_by: actor)

      expect(raw_token).to be_present
      expect(invitation.token_digest).to eq(described_class.digest_token(raw_token))
      expect(invitation.token_digest).not_to include(raw_token)
      expect(invitation.email).to eq("invitee@example.com")
      expect(invitation).to be_usable
    end

    it "revokes a previous usable invitation while preserving its audit row" do
      previous, = described_class.issue!(user: user, email: user.email, invited_by: actor)
      replacement, = described_class.issue!(user: user, email: user.email, invited_by: actor)

      expect(previous.reload).to be_revoked
      expect(previous.revoked_at).to be_present
      expect(previous.revoked_by).to eq(actor)
      expect(replacement).to be_pending
      expect(user.account_invitations.count).to eq(2)
      expect(user.account_invitations.usable).to contain_exactly(replacement)
    end

    it "serializes concurrent issuance so only one invitation remains usable" do
      threads = 2.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            described_class.issue!(user: User.find(user.id), email: user.email, invited_by: actor).first
          end
        end
      end
      invitations = threads.map(&:value)

      expect(invitations.map(&:id).uniq.size).to eq(2)
      expect(user.account_invitations.reload.count).to eq(2)
      expect(user.account_invitations.usable.count).to eq(1)
    end

    it "rejects active and soft-deleted accounts" do
      active_user = create_user(email: "active@example.com", status: :active)
      deleted_user = create_user(email: "deleted@example.com")
      deleted_user.update!(deleted_at: Time.current)

      expect {
        described_class.issue!(user: active_user, email: active_user.email)
      }.to raise_error(ActiveRecord::RecordInvalid)
      expect {
        described_class.issue!(user: deleted_user, email: deleted_user.email)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe ".find_usable_by_token" do
    it "finds an unexpired pending invitation and rejects expired invitations" do
      invitation, token = described_class.issue!(user: user, email: user.email)
      expect(described_class.find_usable_by_token(token)).to eq(invitation)

      invitation.update!(expires_at: 1.second.ago)
      expect(described_class.find_usable_by_token(token)).to be_nil
    end
  end

  describe "validations" do
    it "requires the invitation email to match the user's current normalized email" do
      invitation = described_class.new(
        user: user,
        email: "other@example.com",
        token_digest: described_class.digest_token("token"),
        expires_at: 7.days.from_now
      )

      expect(invitation).not_to be_valid
      expect(invitation.errors[:email]).to include("must match the user's current email")
    end
  end
end
