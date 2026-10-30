# frozen_string_literal: true

# Isolated full-stack browser-test environment. It mirrors the safety
# characteristics of test while running as a long-lived Puma process.
Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV["CI"].present?
  config.consider_all_requests_local = true
  config.server_timing = false
  config.cache_store = :null_store
  config.public_file_server.enabled = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }
  config.action_dispatch.show_exceptions = :rescuable
  config.action_controller.allow_forgery_protection = false
  config.active_storage.service = :test
  config.active_job.queue_adapter = :test
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = { host: "127.0.0.1", port: 3100 }
  config.active_support.deprecation = :stderr
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "warn")
end
