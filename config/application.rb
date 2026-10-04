require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Load the mail transport adapters eagerly. They are referenced by the
# "email_delivery.brevo" initializer below, which runs before Zeitwerk
# autoloading is set up during boot, so lib/ cannot autoload them at that
# point. (Zeitwerk dedups by file path, so these explicit requires do not
# conflict with config.autoload_lib managing lib/ later in the boot.)
require_relative "../lib/http_mail_delivery"
require_relative "../lib/brevo_delivery"
require_relative "../lib/resend_delivery"
require_relative "../lib/mail_transport"
require_relative "../lib/mail_sender"

module WinePredictionApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Ensure app/services is autoloaded for service objects like LlmSearchService
    config.autoload_paths << Rails.root.join("app", "services")

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Load the full Rails stack so the application can render its own HTML
    # interface as well as serving the existing JSON API.
    config.api_only = false

    # This project began as an API-only application, so it did not have the
    # conventional helper lookup path. Register it for server-rendered views.
    config.helpers_paths << Rails.root.join("app", "helpers")

    # Mail transport selection. Declared as a named initializer AFTER
    # ActionMailer's "action_mailer.set_configs" (which applies the
    # config/environments/* settings), so precedence is deterministic and
    # identical in development and production:
    #
    #   0. MAIL_TRANSPORT=brevo|resend|smtp|file -> explicit override ("auto" =
    #                               the automatic selection below). Handy for
    #                               switching providers without editing the
    #                               other variables.
    #   1. BREVO_API_KEY present -> Brevo HTTP API (HTTPS/443 — the only mail
    #                               transport allowed on Render's free plan,
    #                               which blocks outbound SMTP ports
    #                               25/465/587 since Sep 2025)
    #   1b. RESEND_API_KEY present -> Resend HTTP API (same HTTPS rationale;
    #                               requires a verified sending domain)
    #   2. otherwise             -> whatever the environment file chose:
    #                               :smtp when SMTP_ADDRESS is set (kept as a
    #                               local/paid-plan fallback), else :file
    #                               (tmp/mails)
    #
    # The rules live in MailTransport (lib/mail_transport.rb) so they are
    # unit-tested; an override without its credentials warns and falls back
    # rather than breaking boot or silently stopping mail.
    #
    # Controllers, Devise and mailers stay provider-agnostic: they only build
    # a Mail::Message and call deliver_later. Swapping Brevo for Gmail SMTP,
    # SendGrid, Resend, etc. is a config change here + in the environment
    # files — no application code changes.
    initializer "email_delivery.brevo", after: "action_mailer.set_configs" do
      ActionMailer::Base.add_delivery_method(:brevo, BrevoDelivery,
                                             open_timeout: 10,
                                             read_timeout: 10)
      ActionMailer::Base.add_delivery_method(:resend, ResendDelivery,
                                             open_timeout: 10,
                                             read_timeout: 10)

      next if Rails.env.test?

      case MailTransport.resolve(ENV, logger: Rails.logger)
      when "brevo"
        ActionMailer::Base.delivery_method = :brevo
        ActionMailer::Base.brevo_settings = {
          api_key: ENV["BREVO_API_KEY"],
          open_timeout: 10,
          read_timeout: 10
        }
      when "resend"
        ActionMailer::Base.delivery_method = :resend
        ActionMailer::Base.resend_settings = {
          api_key: ENV["RESEND_API_KEY"],
          open_timeout: 10,
          read_timeout: 10
        }
      when "smtp"
        # SMTP settings come from the environment file's SMTP block; SMTP_ADDRESS
        # is guaranteed to be present when MailTransport selects this transport.
        ActionMailer::Base.delivery_method = :smtp
      when "file"
        ActionMailer::Base.delivery_method = :file
        ActionMailer::Base.file_settings = { location: Rails.root.join("tmp/mails") }
      end
    end
  end
end
