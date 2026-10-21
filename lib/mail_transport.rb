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

  # `override` lets a runtime source (the `mail_transport` app setting) take
  # precedence over the boot-time ENV["MAIL_TRANSPORT"]. It is only consulted
  # when it names a supported transport; anything else falls back to ENV and
  # then to the automatic selection.
  def self.resolve(env, logger: nil, override: nil)
    new(env, logger: logger, override: override).resolve
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
  def self.effective_transport_name(env, logger: nil, override: nil)
    return "test" if Rails.env.test?

    resolve(env, logger: logger, override: override)
  end

  def initialize(env, logger: nil, override: nil)
    @env = env
    @logger = logger
    @override = override
  end

  def resolve
    automatic = automatic_transport
    requested = requested_transport

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

  # The explicitly requested transport: the runtime override first, then the
  # boot-time ENV variable. An override that is blank or "auto" means "no
  # explicit choice" and lets ENV decide; this keeps the setting's default of
  # "auto" from masking a MAIL_TRANSPORT set in the environment.
  def requested_transport
    override = @override.to_s.strip.downcase
    return override unless override.empty? || override == "auto"

    @env["MAIL_TRANSPORT"].to_s.strip.downcase
    # AppSetting.mail_transport
  end

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
