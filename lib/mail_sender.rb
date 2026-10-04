# frozen_string_literal: true

# Single source of truth for the addresses stamped on outgoing mail, so the
# sender is configurable without touching mailer code and behaves identically
# for every transport (Brevo, Resend, SMTP, file — see lib/mail_transport.rb):
#
#   MAIL_FROM     - From address, e.g. "Wine Words <no-reply@yourdomain>"
#   MAIL_REPLY_TO - inbox that receives replies (should be a real mailbox)
#
# Defaults preserve the addresses the mailers used before this helper existed.
# Mailers evaluate `default from:` at class-load time, so set the variables in
# the environment (.env.development / Render dashboard) before booting.
module MailSender
  DEFAULT_FROM = "kasia@mywineadviser.com.au"
  DEFAULT_REPLY_TO = "romalopes@yahoo.com.br"

  module_function

  # From address (MAIL_FROM, falling back to the default sender).
  def from(env = ENV)
    lookup("MAIL_FROM", DEFAULT_FROM, env)
  end

  # Reply-To address (MAIL_REPLY_TO, falling back to the default reply inbox).
  def reply_to(env = ENV)
    lookup("MAIL_REPLY_TO", DEFAULT_REPLY_TO, env)
  end

  def lookup(key, default, env)
    value = env[key].to_s.strip
    value.empty? ? default : value
  end
  private_class_method :lookup
end
