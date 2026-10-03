require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Load the Brevo mail transport adapter eagerly. It is referenced by the
# "email_delivery.brevo" initializer below, which runs before Zeitwerk
# autoloading is set up during boot, so lib/ cannot autoload it at that point.
# (Zeitwerk dedups by file path, so this explicit require does not conflict
# with config.autoload_lib managing lib/ later in the boot.)
require_relative "../lib/brevo_delivery"

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
    #   1. BREVO_API_KEY present -> Brevo HTTP API (HTTPS/443 — the only mail
    #                               transport allowed on Render's free plan,
    #                               which blocks outbound SMTP ports
    #                               25/465/587 since Sep 2025)
    #   2. otherwise             -> whatever the environment file chose:
    #                               :smtp when SMTP_ADDRESS is set (kept as a
    #                               local/paid-plan fallback), else :file
    #                               (tmp/mails)
    #
    # Controllers, Devise and mailers stay provider-agnostic: they only build
    # a Mail::Message and call deliver_later. Swapping Brevo for Gmail SMTP,
    # SendGrid, Resend, etc. is a config change here + in the environment
    # files — no application code changes.
    initializer "email_delivery.brevo", after: "action_mailer.set_configs" do
      ActionMailer::Base.add_delivery_method(:brevo, BrevoDelivery,
                                             open_timeout: 10,
                                             read_timeout: 10)

      next if Rails.env.test?
      next if ENV["BREVO_API_KEY"].blank?

      ActionMailer::Base.delivery_method = :brevo
      ActionMailer::Base.brevo_settings = {
        api_key: ENV["BREVO_API_KEY"],
        open_timeout: 10,
        read_timeout: 10
      }
    end
  end
end
