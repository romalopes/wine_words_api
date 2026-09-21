class ApplicationMailer < ActionMailer::Base
  default from: "romalopes@gmail.com"
  layout "mailer"

  # Email testing (Configuration page): when "use_test_email" is on, every
  # outgoing mail is redirected to the configured test address instead of its
  # real recipients, with a [TEST] subject prefix. Off = normal delivery.
  def mail(headers = {}, &block)
    if AppSetting.use_test_email?
      headers = headers.merge(
        to: AppSetting.test_email,
        cc: nil,
        bcc: nil,
        subject: "[TEST] #{headers[:subject]}"
      )
    end
    super
  end
end
