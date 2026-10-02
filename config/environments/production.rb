require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # config.active_storage.service = :local
  config.active_storage.service = :cloudflare_r2


  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"


  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use
  # secure cookies as defined below, unless DISABLE_FORCE_SSL is set.
  # The deployed app sits behind a TLS-terminating proxy (Render's edge, with
  # Thruster in front of Puma inside the container), which forwards
  # X-Forwarded-Proto: https, so this is a no-op there.
  #
  # Running `rails server -e production` locally has NO TLS terminator: this
  # redirects every request to https://localhost:3000, and the browser then
  # speaks TLS to plain Puma - Puma logs "Invalid HTTP format ... Are you
  # trying to open an SSL connection to a non-SSL Puma?", while browsers show
  # ERR_SSL_PROTOCOL_ERROR. It also pins an HSTS entry for `localhost` in the
  # browser (Rails defaults HSTS to 2 years), which keeps upgrading localhost
  # requests to HTTPS even after this is disabled - clear it at
  # chrome://net-internals/#hsts ("Delete domain security policies").
  #
  # Opt out for local runs with DISABLE_FORCE_SSL=true. Render never sets that
  # variable, so the deployed service keeps forcing SSL.
  config.force_ssl = ENV["DISABLE_FORCE_SSL"] != "true"

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "debug")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  # Solid Queue shares the primary database connection on Render. If you
  # ever add a separate `queue:` sub-connection to config/database.yml,
  # change this to: config.solid_queue.connects_to = { database: { writing: :queue } }

config.logger = ActiveSupport::Logger.new("log/production.log")
# OR
  # config.logger = ActiveSupport::Logger.new(STDOUT)


  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "example.com")
  }

  # Use the in‑process async queue for Active Job (zero extra infrastructure)
  config.active_job.queue_adapter = :async

  # Outgoing SMTP server (Gmail app password or any generic SMTP host).
  if ENV["SMTP_ADDRESS"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV["SMTP_ADDRESS"],
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      domain: ENV.fetch("SMTP_DOMAIN", "localhost"),
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
      enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS", "true") == "true",
      open_timeout: 15,
      read_timeout: 10
    }
  # else
  #   config.action_mailer.delivery_method = :file
  #   config.action_mailer.file_settings = { location: Rails.root.join("tmp/mails") }
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
