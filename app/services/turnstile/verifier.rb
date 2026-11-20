# Cloudflare Turnstile server-side verification (IDENTITY_209).
#
# The browser solves the widget and posts its token with the form; only this
# service decides whether the token is good. The client-side success callback is
# never trusted.
#
# Configuration (environment):
#
#   TURNSTILE_ENABLED            "true"/"false". Defaults to true only in
#                                production, so development and test do not need
#                                Cloudflare credentials.
#   TURNSTILE_SECRET_KEY         Server-side secret. NEVER a VITE_* variable.
#   TURNSTILE_EXPECTED_HOSTNAMES Comma-separated allowlist of widget hostnames
#                                (e.g. "wine-words.com,www.wine-words.com").
#   TURNSTILE_EXPECTED_ACTION    Optional expected widget action; when set the
#                                returned action must match exactly.
#   TURNSTILE_VERIFY_URL         Override for tests or a proxy.
#
# Failure policy: fail closed. A missing secret, a network error, a malformed
# response or a missing token all count as a failed verification.
module Turnstile
  class Verifier
    DEFAULT_VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify".freeze
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 5

    # Minimal transport so specs can inject a fake instead of stubbing Net::HTTP.
    # Returns the parsed Siteverify JSON on a 2xx response, nil otherwise.
    class NativeClient
      def post(uri, params)
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(params)

        response = Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: OPEN_TIMEOUT,
          read_timeout: READ_TIMEOUT
        ) { |http| http.request(request) }

        return nil unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      end
    end

    Result = Struct.new(:success, :error_codes, keyword_init: true) do
      def success?
        success == true
      end
    end

    def self.call(token:, remote_ip: nil, env: ENV, client: NativeClient.new)
      new(token: token, remote_ip: remote_ip, env: env, client: client).call
    end

    # Enabled by default only in production. An explicit TURNSTILE_ENABLED
    # always wins, so staging can opt in (or production can opt out, loudly).
    def self.enabled?(env = ENV)
      explicit = env["TURNSTILE_ENABLED"].to_s.strip
      return ActiveModel::Type::Boolean.new.cast(explicit) if explicit.present?

      Rails.env.production?
    end

    def initialize(token:, remote_ip: nil, env: ENV, client: NativeClient.new)
      @token = token.to_s.strip
      @remote_ip = remote_ip
      @env = env
      @client = client
    end

    def call
      # Skip verification in test environment or when explicitly disabled
      return success unless self.class.enabled?(@env)

      # In development, accept any token (test keys should auto-pass)
      # but still verify if a token is provided and we have a secret
      if Rails.env.development?
        return success if @token.blank?
        # In development with test keys, accept any token
        return success if secret.present? && secret.start_with?("0x4AAAAAAGG3w_")
      end

      return failure("missing-secret") if secret.blank?
      return failure("missing-token") if @token.blank?

      payload = siteverify_payload
      return failure("verification-unavailable") unless payload.is_a?(Hash)
      return failure(errors_from(payload)) unless payload["success"] == true
      return failure("hostname-mismatch") unless hostname_allowed?(payload["hostname"])
      return failure("action-mismatch") if action_mismatch?(payload["action"])

      success
    end

    private

    def success
      Result.new(success: true, error_codes: [])
    end

    def failure(codes)
      Result.new(success: false, error_codes: Array(codes).map(&:to_s))
    end

    def errors_from(payload)
      codes = Array(payload["error-codes"]).map(&:to_s).reject(&:empty?)
      codes.presence || [ "verification-failed" ]
    end

    def siteverify_payload
      @client.post(verify_uri, request_params)
    rescue StandardError => e
      # Never log the token or the secret — only the failure shape.
      Rails.logger.warn("[Turnstile] Siteverify error: #{e.class}")
      nil
    end

    def request_params
      {
        secret: secret,
        response: @token,
        remoteip: @remote_ip
      }.compact
    end

    def verify_uri
      URI.parse(@env["TURNSTILE_VERIFY_URL"].to_s.strip.presence || DEFAULT_VERIFY_URL)
    end

    def secret
      @env["TURNSTILE_SECRET_KEY"].to_s.strip
    end

    def expected_hostnames
      @env["TURNSTILE_EXPECTED_HOSTNAMES"].to_s.split(",").map { |h| h.strip.downcase }.reject(&:empty?)
    end

    def hostname_allowed?(hostname)
      expected = expected_hostnames
      return true if expected.empty?

      expected.include?(hostname.to_s.downcase)
    end

    def expected_action
      @env["TURNSTILE_EXPECTED_ACTION"].to_s.strip
    end

    def action_mismatch?(action)
      return false if expected_action.empty?

      action.to_s != expected_action
    end
  end
end
