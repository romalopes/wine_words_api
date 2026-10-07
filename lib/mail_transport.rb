# frozen_string_literal: true

# Decides which ActionMailer delivery method the app uses. Kept out of the
# Rails initializer so the precedence rules are unit-testable and independent
# of boot order.
#
# Rules:
#   MAIL_TRANSPORT=brevo|resend|smtp|file -> explicit override ("auto" or
#                                     blank = automatic selection)
#   otherwise                      -> BREVO_API_KEY -> RESEND_API_KEY ->
#                                     SMTP_ADDRESS -> file
#
# An override that lacks its credentials (e.g. MAIL_TRANSPORT=brevo without a
# key) is ignored, with a warning, and the automatic selection is used instead.
# That way a mistyped variable can never break boot or silently stop mail.
class MailTransport
  SUPPORTED = %w[ brevo resend smtp file ].freeze

  def self.resolve(env, logger: nil)
    new(env, logger: logger).resolve
  end

  # The transport name to surface in diagnostics.
  #
  # In the test environment the mail delivery is handled by the Active Job
  # test delivery, so the name reported here is the literal `"test"` — this
  # keeps the health check honest when the process is exercising
  # `MAIL_TRANSPORT=file` as `file` but the rails `test` delivery is active
  # (CI/output-mode shells), instead of silently quoting a non-existent
  # live transport.
  #
  # Otherwise this resolves the transport name the operator requested, just
  # like {.resolve}.
  def self.effective_transport_name(env, logger: nil)
    return "test" if Rails.env.test?

    resolve(env, logger: logger)
  end

  def initialize(env, logger: nil)
    @env = env
    @logger = logger
  end

  def resolve
    automatic = automatic_transport
    requested = @env["MAIL_TRANSPORT"].to_s.strip.downcase
    if requested.empty? || requested == "auto"
      warn_multiple_keys(automatic)
      return automatic
    end

    unless SUPPORTED.include?(requested)
      warn_about("Unknown MAIL_TRANSPORT=#{requested.inspect}", automatic)
      return automatic
    end

    if requested == "brevo" && !present?(@env["BREVO_API_KEY"])
      warn_about("MAIL_TRANSPORT=brevo requires BREVO_API_KEY", automatic)
      return automatic
    end

    if requested == "resend" && !present?(@env["RESEND_API_KEY"])
      warn_about("MAIL_TRANSPORT=resend requires RESEND_API_KEY", automatic)
      return automatic
    end

    if requested == "smtp" && !present?(@env["SMTP_ADDRESS"])
      warn_about("MAIL_TRANSPORT=smtp requires SMTP_ADDRESS", automatic)
      return automatic
    end

    requested
  end

  private

  def automatic_transport
    return "brevo" if present?(@env["BREVO_API_KEY"])
    return "resend" if present?(@env["RESEND_API_KEY"])
    return "smtp" if present?(@env["SMTP_ADDRESS"])

    "file"
  end

  def present?(value)
    !value.to_s.strip.empty?
  end

  def warn_multiple_keys(selected)
    keys = %w[ BREVO_API_KEY RESEND_API_KEY ].select { |key| present?(@env[key]) }
    return unless keys.size > 1
    return unless @logger

    @logger.warn("[email_delivery] #{keys.join(' and ')} are both set; using #{selected} — " \
                 "set MAIL_TRANSPORT to choose explicitly.")
  end

  def warn_about(reason, fallback)
    return unless @logger

    @logger.warn("[email_delivery] #{reason}; using #{fallback} instead.")
  end
end
