require "rails_helper"

# The contact alert email (IDENTITY_209 Phase 2). One message per configured
# recipient; the visitor's address is used as Reply-To, never as From.
RSpec.describe ContactMessagesMailer, type: :mailer do
  let(:message) do
    ContactMessage.create!(
      name: "Jane <Smith>",
      email: "jane@example.com",
      contact_type: "business",
      subject: "Partnership\r\nBcc: evil@example.com",
      message: "<script>alert('xss')</script>\nSecond line"
    )
  end

  def mail_for(recipient = "team@example.com")
    described_class.notification(message.id, recipient)
  end

  it "addresses exactly one configured recipient" do
    mail = mail_for

    expect(mail.to).to eq([ "team@example.com" ])
    expect(mail.cc).to be_blank
    expect(mail.bcc).to be_blank
  end

  it "keeps the application sender and replies to the visitor" do
    mail = mail_for

    expect(mail.from).to eq([ Mail::Address.new(MailSender.from).address ])
    expect(mail.reply_to).to eq([ "jane@example.com" ])
  end

  it "sanitises the subject so it cannot inject headers" do
    mail = mail_for

    expect(mail.subject).to eq("New contact message — Partnership Bcc: evil@example.com")
    expect(mail.header["bcc"].to_s).to be_blank
  end

  it "includes the sender, category, subject, body and inbox link" do
    mail = mail_for

    expect(mail.subject).to include("Partnership")
    expect(mail.text_part.body.to_s).to include("jane@example.com")
    expect(mail.text_part.body.to_s).to include("business")
    expect(mail.text_part.body.to_s).to include("Second line")
    expect(mail.text_part.body.to_s).to include("/settings/contact-messages/#{message.id}")
  end

  it "escapes user-controlled content in the HTML part" do
    html = mail_for.html_part.body.to_s

    expect(html).to include("&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;")
    expect(html).to include("Jane &lt;Smith&gt;")
    expect(html).not_to include("<script>alert")
  end

  it "keeps the content readable in the plain-text part" do
    text = mail_for.text_part.body.to_s

    expect(text).to include("<script>alert('xss')</script>")
  end
end
