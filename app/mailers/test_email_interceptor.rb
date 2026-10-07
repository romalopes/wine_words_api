# frozen_string_literal: true

# Interceptor that redirects every outgoing e‑mail to a single test address
# when AppSetting.use_test_email? is true.
class TestEmailInterceptor
  def self.delivering_email(message)

    return unless AppSetting.use_test_email?

    test_addr = AppSetting.test_email

    # Replace all recipient fields with the test address
    message.to  = [test_addr]
    message.cc  = [test_addr] if message.cc.present?
    message.bcc = [test_addr] if message.bcc.present?

    # Prefix subject so it's obvious this is a test delivery
    message.subject = "[TEST] #{message.subject}" unless message.subject&.start_with?("[TEST]")
  end
end