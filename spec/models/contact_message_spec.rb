require "rails_helper"

# ContactMessage is the persisted record behind the public Contact form
# (IDENTITY_209 Phase 1). These specs pin the allowlists, normalisation,
# boundaries and the read/unread/archive state machine.
RSpec.describe ContactMessage, type: :model do
  def build_message(overrides = {})
    described_class.new(
      {
        name: "Jane Smith",
        email: "Jane.Smith@Example.com",
        contact_type: "general",
        subject: "A question",
        message: "Could you tell me more about Wine Words?"
      }.merge(overrides)
    )
  end

  it "is valid with the supported fields and defaults to unread" do
    message = build_message

    expect(message).to be_valid
    expect(message.status).to eq("unread")
  end

  it "normalises whitespace, email case and contact type" do
    message = build_message(
      name: "  Jane Smith  ",
      email: "  Jane.Smith@Example.COM ",
      contact_type: "Wine_Submission",
      subject: "  A question  ",
      message: "  Hello there.  "
    )

    expect(message).to be_valid
    expect(message.name).to eq("Jane Smith")
    expect(message.email).to eq("jane.smith@example.com")
    expect(message.contact_type).to eq("wine_submission")
    expect(message.subject).to eq("A question")
    expect(message.message).to eq("Hello there.")
  end

  it "requires every public field" do
    %i[name email contact_type subject message].each do |attribute|
      message = build_message(attribute => nil)

      expect(message).not_to be_valid
      expect(message.errors[attribute]).to be_present
    end
  end

  it "rejects an invalid email address" do
    expect(build_message(email: "not-an-email")).not_to be_valid
    expect(build_message(email: "jane@example.com")).to be_valid
  end

  it "rejects email header injection" do
    message = build_message(email: "jane@example.com\r\nBcc: evil@example.com")

    expect(message).not_to be_valid
    expect(message.errors[:email]).to be_present
  end

  it "accepts only the allowlisted contact types" do
    described_class::CONTACT_TYPES.each do |type|
      expect(build_message(contact_type: type)).to be_valid
    end

    expect(build_message(contact_type: "spam")).not_to be_valid
  end

  it "accepts only the supported statuses" do
    described_class::STATUSES.each do |status|
      expect(build_message(status: status)).to be_valid
    end

    expect(build_message(status: "deleted")).not_to be_valid
  end

  it "enforces the maximum lengths" do
    expect(build_message(name: "a" * 121)).not_to be_valid
    expect(build_message(email: "#{'a' * 250}@example.com")).not_to be_valid
    expect(build_message(subject: "a" * 181)).not_to be_valid
    expect(build_message(message: "a" * 10_001)).not_to be_valid

    expect(build_message(subject: "a" * 180)).to be_valid
    expect(build_message(message: "a" * 10_000)).to be_valid
  end

  it "treats a whitespace-only body as empty" do
    expect(build_message(message: "   \n  ")).not_to be_valid
  end

  it "searches name, email and subject case-insensitively with LIKE escaping" do
    jane = build_message(name: "Jane Smith", subject: "Question").tap(&:save!)
    bob = build_message(
      name: "Bob Jones", email: "bob@example.com", subject: "Partnership"
    ).tap(&:save!)
    percent = build_message(
      name: "Percent", email: "percent@example.com", subject: "100% oak"
    ).tap(&:save!)

    expect(described_class.search("JANE")).to contain_exactly(jane)
    expect(described_class.search("bob@example")).to contain_exactly(bob)
    expect(described_class.search("partner")).to contain_exactly(bob)
    expect(described_class.search("100%")).to contain_exactly(percent)
    expect(described_class.search("")).to eq(described_class.all)
  end

  describe "status transitions" do
    let(:message) { build_message.tap(&:save!) }

    it "marks a message read and stamps read_at" do
      message.mark_read!

      expect(message.status).to eq("read")
      expect(message.read_at).to be_present
      expect(message.archived_at).to be_nil
    end

    it "clears read_at when marked unread again" do
      message.mark_read!
      message.mark_unread!

      expect(message.reload.status).to eq("unread")
      expect(message.read_at).to be_nil
    end

    it "archives without marking read and keeps read_at untouched" do
      message.archive!

      expect(message.reload.status).to eq("archived")
      expect(message.archived_at).to be_present
      expect(message.read_at).to be_nil
      expect(described_class.unread).not_to include(message)
    end

    it "unarchives when an archived message is marked read or unread" do
      message.archive!
      message.mark_read!

      expect(message.reload.status).to eq("read")
      expect(message.archived_at).to be_nil

      message.archive!
      message.mark_unread!

      expect(message.reload.status).to eq("unread")
      expect(message.archived_at).to be_nil
    end

    it "is idempotent" do
      message.mark_read!
      first_read_at = message.read_at

      message.mark_read!
      message.archive!
      message.archive!

      expect(message.reload.read_at).to eq(first_read_at)
      expect(message.status).to eq("archived")
    end

    it "rejects an unsupported status" do
      expect { message.apply_status!("deleted") }
        .to raise_error(ArgumentError, /unsupported status/)
    end
  end
end
