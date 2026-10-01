class CustomDeviseMailer < Devise::Mailer
  # Ensure the default from address matches the one configured in devise.rb
  default from: 'romalopes@yahoo.com.br'

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