require "jwt"

module Authentication
  # Base class for OpenID Connect-style providers (Google, Apple, Microsoft).
  #
  # Subclasses supply three things and inherit all token validation:
  #
  #   * jwks_url       — where the provider publishes its signing keys
  #   * accepted_issuers — the exact `iss` value(s) we accept
  #   * audience       — the client id this app registered with the provider
  #
  # Signature, algorithm allow-list, issuer, audience and expiry are all
  # verified by the `jwt` gem against the provider's published keys, rather
  # than by reading claims out of an unverified token, so a forged or replayed
  # credential cannot get through.
  class OidcVerifier
    ALGORITHMS = %w[RS256 ES256].freeze

    # @param credential [String] the provider-issued ID token
    # @param nonce [String, nil] the nonce the frontend sent to the provider
    #   (validated when the provider is expected to echo it back)
    # @return [Authentication::Claims]
    def self.verify(credential, nonce: nil)
      new.verify(credential, nonce: nonce)
    end

    def self.configured?
      new.audience.present?
    end

    # Memoised per instance, so a single verification never fetches the key set
    # twice while concurrent requests stay independent.
    def verify(credential, nonce: nil)
      ensure_configured!
      raise invalid_credential if credential.blank?

      payload = decode(credential.to_s)
      require_expiry!(payload)
      validate_nonce!(payload, nonce) if nonce_required?
      claims = build_claims(payload)
      # `sub` is the authentication identity key; a token without one cannot be
      # tied to a stable identity and must not be accepted.
      raise invalid_credential if claims.provider_uid.blank?

      claims
    end

    # --- Provider contract -------------------------------------------------
    # Subclasses must implement these three.

    def jwks_url
      raise NotImplementedError
    end

    def accepted_issuers
      raise NotImplementedError
    end

    def audience
      raise NotImplementedError
    end

    # Apple requires the nonce it echoed back to match the one React sent.
    # Google/Microsoft bind the flow to the audience instead.
    def nonce_required?
      false
    end

    private

    def ensure_configured!
      return if self.class.configured?

      Rails.logger.error("[authentication] #{provider_name} is not configured")
      raise Authentication::Error.new(
        "This sign-in method is not available right now.",
        code: :provider_not_configured, status: :service_unavailable
      )
    end

    def decode(token)
      payload, = JWT.decode(
        token,
        nil,
        true,
        algorithms: ALGORITHMS,
        # The jwt gem resolves the verification key from the token header's kid
        # against the provider's published JWKS — never from anything inside the
        # token body — and asks our loader to refetch when it sees an unknown
        # kid. A token without a kid cannot be tied to a published key and is
        # rejected (allow_nil_kid: false).
        jwks: jwks.loader,
        allow_nil_kid: false,
        iss: accepted_issuers,
        verify_iss: true,
        aud: audience,
        verify_aud: true,
        verify_expiration: true,
        verify_iat: false,
        exp_leeway: 30
      )
      payload
    rescue JWT::DecodeError => e
      # ExpiredSignature, InvalidAudienceError, InvalidIssuerError,
      # InvalidSignature, VerificationError etc. all derive from DecodeError.
      # The operator gets the class; the client only ever sees a safe message.
      Rails.logger.warn("[authentication] #{provider_name} token rejected: #{e.class}")
      raise invalid_credential
    end

    def jwks
      @jwks ||= Jwks.new(jwks_url)
    end

    # Every provider we support issues a short-lived ID token with an `exp`
    # claim. The jwt gem only *verifies* an expiry that is present, so a token
    # minted without one would otherwise be accepted indefinitely — reject it
    # explicitly instead.
    def require_expiry!(payload)
      return if payload["exp"].present?

      Rails.logger.warn("[authentication] #{provider_name} token has no exp claim")
      raise invalid_credential
    end

    def invalid_credential
      Authentication::Error.new(
        "The sign-in credential is invalid or has expired. Please try again.",
        code: :invalid_credential, status: :unauthorized
      )
    end

    def validate_nonce!(payload, nonce)
      return if nonce.present? && ActiveSupport::SecurityUtils.secure_compare(
        payload["nonce"].to_s, nonce.to_s
      )

      Rails.logger.warn("[authentication] #{provider_name} nonce mismatch")
      raise Authentication::Error.new(
        "The sign-in request could not be verified. Please try again.",
        code: :invalid_nonce, status: :unauthorized
      )
    end

    # Default claim mapping shared by Google/Apple/Microsoft: `sub` is the
    # stable provider identity, and the email is only trusted as "verified"
    # when the provider asserts it (Google's email_verified claim). Subclasses
    # override for provider quirks.
    def build_claims(payload)
      Claims.new(
        provider: provider_name,
        provider_uid: payload["sub"],
        email: payload["email"],
        name: payload["name"],
        email_verified: email_verified?(payload)
      )
    end

    def email_verified?(payload)
      value = payload["email_verified"]
      value == true || value.to_s == "true"
    end

    def provider_name
      self.class.name.demodulize.underscore
    end
  end
end