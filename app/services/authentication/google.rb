require "jwt"

module Authentication
  # Google Sign-In (Google Identity Services / OpenID Connect).
  #
  # React renders the Google button and receives an ID token ("credential");
  # that token is posted here and verified against Google's published keys.
  # Google's client secret is never needed — and is never exposed to the SPA.
  #
  # Identity key: the `sub` claim (stable, opaque, per Google account). The
  # email is *not* used as the key.
  class Google < OidcVerifier
    JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs".freeze
    ISSUERS = [ "https://accounts.google.com", "accounts.google.com" ].freeze

    def jwks_url
      JWKS_URL
    end

    def accepted_issuers
      ISSUERS
    end

    def audience
      Authentication.google_client_id
    end

    def provider_name
      "google"
    end

    private

    # Google documents `email_verified` as a boolean (older tokens sometimes
    # used the string "true"), so normalise both.
    def email_verified?(payload)
      value = payload["email_verified"]
      value == true || value.to_s == "true"
    end
  end
end