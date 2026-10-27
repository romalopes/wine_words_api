require "rails_helper"

RSpec.describe AccountInvitationService do
  it "serializes concurrent sends so only one email is delivered" do
    user = User.create!(email: "send-race@example.com", account_status: :unclaimed)
    actor = User.create!(email: "send-actor@example.com", password: "password123")
    delivered = Concurrent::AtomicFixnum.new
    delivery = instance_double(ActionMailer::MessageDelivery)
    allow(delivery).to receive(:deliver_now) { delivered.increment }
    allow(AccountInvitationsMailer).to receive(:invitation).and_return(delivery)

    results = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          described_class.issue!(user: User.find(user.id), actor:)
          :sent
        rescue described_class::Error => e
          e.code
        end
      end
    end.map(&:value)

    expect(results.count(:sent)).to eq(1)
    expect(results.count("invitation_rate_limited")).to eq(1)
    expect(delivered.value).to eq(1)
    expect(user.account_invitations.count).to eq(1)
  end
end
