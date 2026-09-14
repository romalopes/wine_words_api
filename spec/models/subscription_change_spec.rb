require "rails_helper"

RSpec.describe SubscriptionChange, type: :model do
  let(:user) do
    User.create!(user_name: "roma", email: "sc@example.com", password: "password123")
  end

  it "requires a known change_type" do
    expect {
      user.subscription_changes.create!(change_type: "bogus", status: "pending")
    }.to raise_error(ArgumentError, /is not a valid change_type/)
  end

  it "enforces a unique idempotency_key per user" do
    user.subscription_changes.create!(
      change_type: "upgrade", status: "pending", idempotency_key: "key-1"
    )
    duplicate = user.subscription_changes.build(
      change_type: "upgrade", status: "pending", idempotency_key: "key-1"
    )
    expect(duplicate).to be_invalid
  end

  it "exposes status scopes" do
    user.subscription_changes.create!(
      change_type: "downgrade", status: "scheduled",
      effective_at: 1.day.from_now
    )
    expect(user.subscription_changes.scheduled.count).to eq(1)
    expect(user.subscription_changes.due.count).to eq(0)
  end
end