require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Load the mail transport adapters eagerly. They are referenced by the
# "email_delivery.dynamic" initializer below, which runs before Zeitwerk
# autoloading is set up during boot, so lib/ cannot autoload them at that
# point. (Zeitwerk dedups by file path, so these explicit requires do not
# conflict with config.autoload_lib managing lib/ later in the boot.)
require_relative "../lib/http_mail_delivery"
require_relative "../lib/brevo_delivery"
require_relative "../lib/resend_delivery"
require_relative "../lib/mail_transport"
require_relative "../lib/dynamic_delivery"
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
    #   0. AppSetting.mail_transport (runtime override, "auto" = automatic)
    #   1. MAIL_TRANSPORT=brevo|resend|smtp|file -> explicit env override
    #   2. BREVO_API_KEY present -> Brevo HTTP API (HTTPS/443 — the only mail
    #                               transport allowed on Render's free plan,
    #                               which blocks outbound SMTP ports
    #                               25/465/587 since Sep 2025)
    #   2b. RESEND_API_KEY present -> Resend HTTP API (same HTTPS rationale;
    #                               requires a verified sending domain)
    #   3. otherwise             -> SMTP when SMTP_ADDRESS is set, else file
    #                               (tmp/mails)
    #
    # The selection rules live in MailTransport (lib/mail_transport.rb) so they
    # are unit-tested; an override without its credentials warns and falls
    # back rather than breaking boot or silently stopping mail.
    #
    # Instead of pinning ONE provider per process (the old boot-time case
    # statement), the app registers DynamicDelivery as the process-wide
    # delivery method. DynamicDelivery resolves the actual provider on EVERY
    # delivery using the same MailTransport precedence, so an admin can flip
    # the "Delivery method" setting on the Configuration page and the next
    # e-mail already goes out through the new provider — no restart, no
    # redeploy. API keys are read from ENV first and from the app_settings
    # table second (see lib/dynamic_delivery.rb).
    #
    # The test environment keeps the :test delivery method so request specs
    # keep using ActionMailer::Base.deliveries; the initializer's provider
    # registrations below still run there.
    initializer "email_delivery.dynamic", after: "action_mailer.set_configs" do
      ActionMailer::Base.add_delivery_method(:brevo, BrevoDelivery,
                                             open_timeout: 10,
                                             read_timeout: 10)
      ActionMailer::Base.add_delivery_method(:resend, ResendDelivery,
                                             open_timeout: 10,
                                             read_timeout: 10)
      ActionMailer::Base.add_delivery_method(:dynamic, DynamicDelivery)

      next if Rails.env.test? || Rails.env.e2e?

      ActionMailer::Base.delivery_method = :dynamic

      # Log the boot-time resolution for observability. This is only a
      # snapshot — DynamicDelivery re-resolves on every delivery, so a later
      # runtime change (AppSetting.mail_transport) takes effect immediately
      # without a restart.
      Rails.logger.info(
        "[email_delivery] DynamicDelivery active; boot-time transport: " \
        "#{MailTransport.resolve(ENV, logger: Rails.logger)}"
      )
    end
  end
end
