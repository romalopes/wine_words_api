# frozen_string_literal: true

require_relative "http_mail_delivery"
require_relative "mail_transport"

# Runtime-switchable delivery adapter.
#
# ActionMailer picks one delivery method per process (at boot), which makes it
# impossible to switch providers without a redeploy. This adapter is registered
# as the process-wide delivery method (see config/application.rb) and resolves
# the *actual* provider on every single delivery, so an admin can flip the
# "Delivery method" setting on the Configuration page and the next e-mail
# already goes out through the new provider — no restart, no deploy.
#
# Resolution order for the transport of a given message:
#
#   1. an explicit per-message transport (delivery_method_options[:transport]),
#      used by the health diagnostics to probe one specific provider;
#   2. the "mail_transport" app setting (runtime override);
#   3. MAIL_TRANSPORT from the environment (boot-time override);
#   4. automatic selection: BREVO_API_KEY -> RESEND_API_KEY -> SMTP -> file.
#
# API keys are read from the environment first and from the app_settings table
# second, so credentials can also be supplied at runtime (admin-managed
# settings) without touching the deployment.
#
# The providers themselves stay untouched: BrevoDelivery/ResendDelivery (HTTP
# APIs), Mail::SMTP and Mail::FileDelivery are the leaf delivery methods; this
# class only decides *which* one handles the message.
class DynamicDelivery
  # Raised for an unknown transport or missing credentials. Surfaced in the job
  # log because config.action_mailer.raise_delivery_errors = true. Inherits the
  # delivery-layer base so it, like the provider errors, passes through
  # deliver! unwrapped.
  class Error < HttpMailDelivery::DeliveryError; end

  DEFAULT_TIMEOUT = 10

  # Transports this adapter can dispatch to.
  SUPPORTED = %w[ brevo resend smtp file test ].freeze

  # Env var holding the API key of each HTTP provider.
  API_KEY_VARS = { "brevo" => "BREVO_API_KEY", "resend" => "RESEND_API_KEY" }.freeze

  def initialize(settings = {})
    @settings = (settings || {}).to_h.transform_keys(&:to_sym)
  end

  # Mail::Message delivery entry point (called by Mail::Message#do_delivery).
  def deliver!(mail)
    transport = transport_name
    delivery = build_delivery(transport)
    delivery.deliver!(mail)
    true
  rescue HttpMailDelivery::DeliveryError
    # Provider errors (BrevoDelivery::Error, ResendDelivery::Error, ...) and
    # this class's own errors are already fully labelled — re-raise them
    # unwrapped so the job log keeps the specific message and error class.
    raise
  rescue StandardError => e
    raise Error, "#{transport_label(transport)} delivery failed: #{e.class}: #{e.message}"
  end

  # The transport that will handle the next delivery through this adapter.
  #
  # A per-message transport wins over everything else, but only when it names
  # a supported provider; an unknown value falls back to the normal resolution
  # so a typo can never silently disable mail.
  def transport_name
    forced = @settings[:transport].to_s.strip.downcase
    return forced if SUPPORTED.include?(forced)

    MailTransport.resolve(
      runtime_env,
      logger: Rails.logger,
      override: AppSetting.mail_transport
    )
  end

  private

  def build_delivery(transport)
    case transport
    when "brevo"
      BrevoDelivery.new(
        api_key: credential("brevo"),
        open_timeout: timeout(:open_timeout),
        read_timeout: timeout(:read_timeout)
      )
    when "resend"
      ResendDelivery.new(
        api_key: credential("resend"),
        open_timeout: timeout(:open_timeout),
        read_timeout: timeout(:read_timeout)
      )
    when "smtp"
      Mail::SMTP.new(smtp_settings)
    when "file"
      Mail::FileDelivery.new(location: file_location)
    when "test"
      Mail::TestMailer.new({})
    else
      raise Error, "Unsupported mail transport #{transport.inspect}"
    end
  end

  # API key of an HTTP provider: environment first, then the admin-managed
  # app setting. A missing key is reported here with a clear message instead
  # of surfacing as an opaque 401 from the provider.
  def credential(provider)
    key = API_KEY_VARS.fetch(provider)
    value = runtime_env[key].to_s.strip
    raise Error, "#{key} is not configured" if value.empty?

    value
  end

  def timeout(name)
    @settings[name] || DEFAULT_TIMEOUT
  end

  # ENV plus the runtime-managed overrides (app settings), so both the
  # transport selection and the credentials see the same picture.
  def runtime_env
    env = ENV.to_h
    env["BREVO_API_KEY"] = AppSetting.brevo_api_key if env["BREVO_API_KEY"].blank? && AppSetting.brevo_api_key.present?
    env["RESEND_API_KEY"] = AppSetting.resend_api_key if env["RESEND_API_KEY"].blank? && AppSetting.resend_api_key.present?
    env
  end

  def transport_label(transport)
    transport.to_s.capitalize
  end

  # SMTP settings mirror config/environments/production.rb: the same env vars,
  # the same defaults, so switching to SMTP at runtime behaves exactly like
  # booting with SMTP configured.
  def smtp_settings
    {
      address: runtime_env["SMTP_ADDRESS"].presence || "localhost",
      port: runtime_env.fetch("SMTP_PORT", 587).to_i,
      domain: runtime_env.fetch("SMTP_DOMAIN", "localhost"),
      user_name: runtime_env["SMTP_USERNAME"],
      password: runtime_env["SMTP_PASSWORD"],
      authentication: runtime_env.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
      enable_starttls_auto: runtime_env.fetch("SMTP_ENABLE_STARTTLS", "true") == "true",
      open_timeout: timeout(:open_timeout),
      read_timeout: timeout(:read_timeout),
      return_path: runtime_env["MAIL_FROM"]
    }.compact
  end

  def file_location
    Rails.root.join("tmp/mails")
  end
end
