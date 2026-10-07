# frozen_string_literal: true

# Prepares the health-API diagnostics e-mail for delivery.
#
# The class is intentionally plain: it only formats the subject/body so the
# effective transport name can be embedded, then returns the built message.
#
# Delivery is handled by the caller, which allows the global TestEmailInterceptor
# to function when AppSetting.use_test_email? is on. When the feature is enabled,
# the interceptor redirects the email to the configured test address and prefixes
# the subject with [TEST].
#
# Action Mailer autoloads this file from app/mailers/, so it is available as
# `TestEmailMailer` without any additional require.
class TestEmailMailer < ApplicationMailer
  def self.test_email(to:, content:, transport:, subject: nil, transport_note: nil)
    new.test_email(to: to, content: content, transport: transport, subject: subject, transport_note: transport_note)
  end

  # Builds the diagnostics message and returns it for delivery.
  #
  # This is a single-write flow: the message is built once for the caller's
  # recipient and nothing is persisted here. The caller (the health
  # controller) is responsible for delivery via `deliver_now` to allow the
  # TestEmailInterceptor to function when AppSetting.use_test_email? is on.
  def test_email(to:, content:, transport:, subject: nil, transport_note: nil)
    @sent_to = to
    @sent_content = content
    @effective_transport = transport
    @transport_note = transport_note

    mail(
      to: to,
      subject: subject.presence || "[Email Test] via #{transport}"
    ) do |format|
      format.text { render plain: test_body_text }
      format.html { render plain: test_body_text }
    end
  end

  private

  def test_body_text
    <<~TEXT
      This is a health-API test e-mail.

      Recipient: #{@sent_to.inspect}
      Transport used: #{@effective_transport}
      #{@transport_note if @transport_note.present?}
      Body: #{@sent_content}
    TEXT
  end
end
