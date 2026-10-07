# Unit specs for the health e-mail tool's mailer.
#
# The mailer builds the diagnostics message and delivers it through the
# configured transport. Because the global TestEmailInterceptor rewrites every
# delivery's recipient to the configured test address when
# AppSetting.use_test_email? is on, this mailer forces the recipient fields to
# the caller's values and ships the message through `do_delivery` — the only
# delivery path that skips the interceptor.
require "rails_helper"

RSpec.describe TestEmailMailer, type: :mailer do
  let(:subject) { "Re: the wine tasting notes" }

  let(:recipient) { "jane@doe.com" }
  let(:content) { "Please ignore this e-mail." }
  let(:transport) { "file" }

  # Subject is supplied by the caller: when present it wins over the generated
  # default, so the diagnostics e-mail looks like the application's own inbox.
  it "uses the caller's subject when one is supplied" do
    mail = described_class.test_email(to: recipient, content: content,
                                      transport: transport, subject: subject)

    expect(mail.subject).to eq(subject)
  end

  it "falls back to a generated subject when the caller omits one" do
    mail = described_class.test_email(to: recipient, content: content,
                                      transport: transport)

    expect(mail.subject).to eq("[Email Test] via file")
  end

  it "addresses the caller-supplied recipient, ignoring the test interceptor" do
    mail = described_class.test_email(to: recipient, content: content,
                                      transport: transport, subject: subject)

    expect(mail.to).to eq([recipient])
    expect(mail.cc).to be_nil
    expect(mail.bcc).to be_nil
  end

  it "embeds the effective transport name in the body (the caller's subject wins)" do
    mail = described_class.test_email(to: recipient, content: content,
                                      transport: transport, subject: subject)

    expect(mail.body.encoded).to include("Transport used: file")
    expect(mail.subject).to eq(subject)
  end

  it "embeds the recipient and body content in the message text" do
    mail = described_class.test_email(to: recipient, content: content,
                                      transport: transport, subject: subject)

    expect(mail.body.encoded).to include("Recipient: \"jane@doe.com\"")
    expect(mail.body.encoded).to include(content)
  end

  it "does not deliver the email (delivery is caller's responsibility)" do
    expect {
      described_class.test_email(to: recipient, content: content,
                                 transport: transport, subject: subject)
    }.not_to change(ActionMailer::Base.deliveries, :count)
  end
end
