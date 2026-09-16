require "rails_helper"

RSpec.describe UserIdentity, type: :model do
  def create_user(attrs = {})
    User.create!({ user_name: "Identity User #{SecureRandom.hex(2)}",
                   email: "identity-#{SecureRandom.hex(4)}@example.com",
                   password: "password123" }.merge(attrs))
  end

  let(:user) { create_user }

  describe "associations" do
    it "belongs to a user" do
      identity = described_class.create!(user: user, provider: "google", provider_uid: "g-1")
      expect(identity.user).to eq(user)
    end

    it "is exposed from the user side as user_identities" do
      described_class.create!(user: user, provider: "google", provider_uid: "g-1")
      described_class.create!(user: user, provider: "apple", provider_uid: "a-1")
      expect(user.user_identities.count).to eq(2)
    end
  end

  describe "providers" do
    %w[google apple microsoft facebook].each do |provider|
      it "supports the #{provider} provider" do
        identity = described_class.create!(user: user, provider: provider, provider_uid: "#{provider}-1")
        expect(identity.provider).to eq(provider)
        expect(identity.public_send("#{provider}?")).to be true
      end
    end

    it "rejects an unsupported provider" do
      identity = described_class.new(user: user, provider: "twitter", provider_uid: "t-1")
      expect(identity).not_to be_valid
      expect(identity.errors[:provider]).to be_present
    end
  end

  describe "validations" do
    it "requires a provider" do
      identity = described_class.new(user: user, provider_uid: "x-1")
      expect(identity).not_to be_valid
      expect(identity.errors[:provider]).to be_present
    end

    it "requires a provider_uid" do
      identity = described_class.new(user: user, provider: "google")
      expect(identity).not_to be_valid
      expect(identity.errors[:provider_uid]).to be_present
    end

    it "requires a user" do
      identity = described_class.new(provider: "google", provider_uid: "x-1")
      expect(identity).not_to be_valid
      expect(identity.errors[:user]).to be_present
    end
  end

  describe "uniqueness" do
    it "rejects a duplicate (provider, provider_uid) — the same provider " \
       "identity must never belong to two users" do
      described_class.create!(user: user, provider: "google", provider_uid: "shared-1")
      other = create_user

      duplicate = described_class.new(user: other, provider: "google", provider_uid: "shared-1")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:provider_uid]).to be_present
    end

    it "enforces (provider, provider_uid) uniqueness at the database level" do
      described_class.create!(user: user, provider: "google", provider_uid: "db-1")
      other = create_user

      expect {
        described_class.insert!({
          user_id: other.id, provider: "google", provider_uid: "db-1",
          created_at: Time.current, updated_at: Time.current
        })
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows the same provider_uid under a different provider" do
      described_class.create!(user: user, provider: "google", provider_uid: "same-1")
      other = create_user
      second = described_class.create!(user: other, provider: "microsoft", provider_uid: "same-1")
      expect(second).to be_persisted
    end

    it "rejects connecting the same provider twice to one user" do
      described_class.create!(user: user, provider: "google", provider_uid: "one-1")
      duplicate = described_class.new(user: user, provider: "google", provider_uid: "two-2")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:provider]).to be_present
    end
  end

  describe ".find_identity" do
    it "finds an identity by provider and provider_uid" do
      identity = described_class.create!(user: user, provider: "apple", provider_uid: "sub-9")
      expect(described_class.find_identity("apple", "sub-9")).to eq(identity)
    end

    it "returns nil when the identity is unknown" do
      expect(described_class.find_identity("google", "missing")).to be_nil
    end
  end
end