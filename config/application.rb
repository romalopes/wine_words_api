require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

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
  end
end
