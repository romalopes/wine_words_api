require "rails_helper"

# CONTACT_NOTIFICATION_EMAILS parsing (IDENTITY_209 Phase 2). MAIL_REPLY_TO is
# intentionally never read here — it keeps its Reply-To header meaning.
RSpec.describe ContactMessages::Recipients do
  it "parses, trims, downcases and deduplicates the list" do
    emails = described_class.emails(
      "CONTACT_NOTIFICATION_EMAILS" => " Team@Example.com , second@example.com ; TEAM@example.com "
    )

    expect(emails).to eq([ "team@example.com", "second@example.com" ])
  end

  it "drops invalid addresses and header-injection attempts" do
    emails = described_class.emails(
      "CONTACT_NOTIFICATION_EMAILS" => "ok@example.com,not-an-email,evil@example.com\nBcc: x@example.com"
    )

    expect(emails).to eq([ "ok@example.com" ])
  end

  it "returns an empty list when the variable is blank" do
    expect(described_class.emails({})).to eq([])
    expect(described_class.emails("CONTACT_NOTIFICATION_EMAILS" => "  ")).to eq([])
  end

  it "ignores MAIL_REPLY_TO" do
    emails = described_class.emails("MAIL_REPLY_TO" => "support@example.com")

    expect(emails).to eq([])
  end

  it "accepts a single address" do
    expect(described_class.emails("CONTACT_NOTIFICATION_EMAILS" => "solo@example.com"))
      .to eq([ "solo@example.com" ])
  end
end
