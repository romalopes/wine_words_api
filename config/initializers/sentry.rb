# Initialize Sentry only if DSN is provided
if ENV['SENTRY_DSN'].present?
  Sentry.init do |config|
    config.dsn = ENV['SENTRY_DSN']
    config.environment = Rails.env.to_s
    config.release = AppVersion::VERSION rescue nil

    # Adjust traces sample rate for performance monitoring
    config.traces_sample_rate = Rails.env.production? ? 0.2 : 1.0

    # Breadcrumbs logging
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]

    # Exclude expected exceptions that are not server errors
    config.excluded_exceptions += [
      'ActionController::RoutingError',
      'ActiveRecord::RecordNotFound'
    ]

    # Scrub sensitive data from events
    config.before_send = lambda do |event, hint|
      # Scrub sensitive parameters
      if event.request && event.request.params.is_a?(Hash)
        event.request.params.each do |key, value|
          if key.to_s.match?(/^(password|password_confirmation|token|reset_token|stripe_token|credit_card|cc_number)$/i)
            event.request.params[key] = '[FILTERED]'
          end
        end
      end

      # Scrub sensitive headers
      if event.request && event.request.headers.is_a?(Hash)
        event.request.headers.each do |key, value|
          if key.to_s.match?(/^(authorization|cookie|x-test-access-token)$/i)
            event.request.headers[key] = '[FILTERED]'
          end
        end
      end

      # Scrub user context (PII)
      if event.user && event.user.is_a?(Hash)
        event.user.each do |key, value|
          if key.to_s.match?(/^(email|username|ip_address)$/i)
            event.user[key] = '[FILTERED]'
          end
        end
      end

      event
    end
  end
end
