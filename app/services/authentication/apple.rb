require "jwt"
require "digest"

module Authentication
  # Sign in with Apple.
  #
  # React runs the Apple JS popup and posts back the `identityToken` Apple
  # issued, plus the `nonce` it sent to Apple. The identity token is an ID
  # token signed by Apple and is verified here against Apple's public keys.
  #
  # Identity key: the `sub` claim (stable per Apple account, and per app for
  # "Hide My Email" users). Apple's email may be a private relay address and is
  # therefore never the identity key and never used to auto-link by email —
  # see Authentication::SocialLogin for the documented policy.
  #
  # Apple only returns `email` in the identity token on the *first*
  # authorisation for an app; afterwards it is absent, which is exactly why
  # `sub` must be the key.
  class Apple < OidcVerifier
    JWKS_URL = "https://appleid.apple.com/auth/keys".freeze
    ISSUER = "https://appleid.apple.com".freeze

    def jwks_url
      JWKS_URL
    end

    def accepted_issuers
      ISSUER
    end

    def audience
      Authentication.apple_client_id
    end

    # Apple echoes the nonce the client sent; verifying it binds this ID token
    # to the authorisation request React started (replay protection).
    def nonce_required?
      true
    end

    def provider_name
      "apple"
    end

    private

    # Apple hashes the nonce the client supplied with SHA-256 before placing it
    # in the identity token's `nonce` claim, so the comparison is against the
    # digest rather than the raw value. Comparing the digest (and not the raw
    # string) is what makes a stolen ID token useless on its own: an attacker
    # who can read the token sees only the hash and cannot invert it back into
    # the nonce React generated.
    def validate_nonce!(payload, nonce)
      digest = nonce.present? ? Digest::SHA256.hexdigest(nonce.to_s) : nil

      if digest.present? && payload["nonce"].present? &&
         ActiveSupport::SecurityUtils.secure_compare(payload["nonce"].to_s, digest)
        return
      end

      Rails.logger.warn("[authentication] apple nonce mismatch")
      raise Authentication::Error.new(
        "The sign-in request could not be verified. Please try again.",
        code: :invalid_nonce, status: :unauthorized
      )
    end

    def build_claims(payload)
      Claims.new(
        provider: provider_name,
        provider_uid: payload["sub"],
        email: payload["email"],
        name: payload["name"],
        # Apple has already proven control of the address it returns (it is
        # either the account address or an Apple-issued relay), but a relay
        # address proves nothing about the User's own email, so SocialLogin
        # additionally refuses to auto-link private relay addresses.
        email_verified: payload["email"].present?,
        metadata: { private_relay: payload["is_private_email"].to_s == "true" }
      )
    end
  end
end