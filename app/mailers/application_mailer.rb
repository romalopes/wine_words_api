class ApplicationMailer < ActionMailer::Base
  # Sender is configurable via MAIL_FROM (see lib/mail_sender.rb) and shared
  # with the Devise mailer, so every transport sends the same From address.
  default from: MailSender.from
  layout "mailer"
end
