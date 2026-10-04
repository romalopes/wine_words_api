class CustomDeviseMailer < Devise::Mailer
  # From/Reply-To come from MAIL_FROM / MAIL_REPLY_TO (lib/mail_sender.rb) —
  # the explicit defaults also stop Devise falling back to devise.rb's
  # config.mailer_sender for these headers.
  default from: MailSender.from, reply_to: MailSender.reply_to

  # Override the reset password instructions to respect the test‑email setting.
  def reset_password_instructions(record, token, opts = {})
    if AppSetting.use_test_email?
      opts[:to] = AppSetting.test_email
    end

    super
  end

  # If you also want the same behaviour for other Devise mails, uncomment
  # and adapt the methods below:
  #
  # def confirmation_instructions(record, token, opts = {})
  #   opts[:to] = AppSetting.test_email if AppSetting.use_test_email?
  #   super
  # end
  #
  # def unlock_instructions(record, token, opts = {})
  #   opts[:to] = AppSetting.test_email if AppSetting.use_test_email?
  #   super
  # end
end
