module Authentication
  # Minimal Net::HTTP wrapper for the provider calls we need (JWKS documents,
  # Apple's token endpoint, Facebook's Graph API).
  #
  # Deliberately dependency-free — no new gems — and it never logs request or
  # response bodies, so access tokens, authorization codes and provider secrets
  # can never end up in the application log.
  module HttpClient
    TIMEOUT = 5

    module_function

    def get_json(url, params: nil, headers: {})
      parse(request(Net::HTTP::Get, url, params: params, headers: headers))
    end

    def post_form_json(url, form:, headers: {})
      parse(request(Net::HTTP::Post, url, form: form, headers: headers))
    end

    def request(request_class, url, params: nil, form: nil, headers: {})
      uri = URI.parse(url)
      uri.query = URI.encode_www_form(params) if params.present?

      request = request_class.new(uri.request_uri)
      headers.each { |name, value| request[name] = value }
      if form.present?
        request.set_form_data(form)
        request["Content-Type"] ||= "application/x-www-form-urlencoded"
      end

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        raise Authentication::Error.new(
          "The identity provider rejected the request.",
          code: :provider_error, status: :bad_gateway
        )
      end

      response.body
    rescue Authentication::Error
      raise
    rescue StandardError => e
      # Never surface network internals (hostnames, TLS errors, timeouts) to
      # the client; log the class only.
      Rails.logger.error("[authentication] provider request failed: #{e.class}")
      raise Authentication::Error.new(
        "Could not reach the identity provider. Please try again.",
        code: :provider_unavailable, status: :service_unavailable
      )
    end

    def parse(body)
      JSON.parse(body.to_s)
    rescue JSON::ParserError
      raise Authentication::Error.new(
        "Unexpected response from the identity provider.",
        code: :provider_error, status: :bad_gateway
      )
    end
  end
end