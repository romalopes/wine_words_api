require "rails_helper"

# One email per configured recipient (IDENTITY_209 Phase 2). Delivery failures
# are retried and can never delete the persisted message.
RSpec.describe ContactMessages::EmailJob, type: :job do
  let(:message) do
    ContactMessage.create!(
      name: "Jane Smith",
      email: "jane@example.com",
      contact_type: "general",
      subject: "Hello",
      message: "A question"
    )
  end

  it "delivers one email to the given recipient" do
    expect do
      described_class.perform_now(message.id, "team@example.com")
    end.to change { ActionMailer::Base.deliveries.count }.by(1)

    delivered = ActionMailer::Base.deliveries.last
    expect(delivered.to).to eq([ "team@example.com" ])
    expect(delivered.reply_to).to eq([ "jane@example.com" ])
  end

  it "keeps the message when delivery fails and schedules a retry" do
    allow(ContactMessagesMailer).to receive(:notification).and_raise(StandardError, "smtp down")

    expect do
      described_class.perform_now(message.id, "team@example.com")
    end.not_to raise_error

    expect(ContactMessage.exists?(message.id)).to be(true)
    expect(described_class).to have_been_enqueued
  end

  it "discards a job for a message that no longer exists" do
    expect do
      described_class.perform_now(999_999, "team@example.com")
    end.not_to raise_error
  end
end
