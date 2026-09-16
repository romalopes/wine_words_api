module Authentication
  # Facebook Login (Meta).
  #
  # The Facebook JS SDK hands React a *user access token*, not an ID token, so
  # there is no signature to check locally. Instead the token is validated
  # against Meta's Graph API:
  #
  #   1. GET /debug_token (authenticated with the app access token
  #      "APP_ID|APP_SECRET") proves the token is valid, unexpired, and was
  #      issued to *our* app. This is the step that makes a forged or
  #      third-party token unusable, and it is why the frontend merely
  #      forwarding a token is not a vulnerability.
  #   2. GET /me then reads the identity *using the validated token*, rather
  #      than trusting any id/email the SPA might have sent.
  #
  # Identity key: the app-scoped user `id` returned by /me (stable per app).
  # Only `public_profile` and `email` are requested — no extra permissions.
  #
  # FACEBOOK_APP_SECRET stays server-side and is never exposed to React.
  #
  # EMAIL-LINKING POLICY: Meta returns an address only when it holds a
  # confirmed one, but supplies no per-token "verified" signal, so a Facebook
  # address is deliberately NOT treated as verified for automatic account
  # linking. Facebook sign-in therefore resolves by provider identity first,
  # and on an email collision asks the person to sign in with their existing
  # method and connect Facebook from Account settings (see
  # Authentication::SocialLogin). This avoids ever attaching an identity to
  # somebody else's account on the strength of an unproven address.
  class Facebook
    def self.verify(credential, nonce: nil)
      new.verify(credential, nonce: nonce)
    end

    def self.configured?
      Authentication.facebook_app_id.present? && Authentication.facebook_app_secret.present?
    end

    def verify(credential, nonce: nil)
      ensure_configured!
      raise invalid_credential if credential.blank?

      # Step 1: validate the token itself (validity, expiry, our app).
      token = debug_token(credential.to_s)

      # Step 2: read the identity with the now-validated token.
      profile = fetch_profile(credential.to_s)
      uid = profile["id"].presence

      raise invalid_credential if uid.blank? || token["user_id"].to_s != uid.to_s

      Claims.new(
        provider: "facebook",
        provider_uid: uid,
        email: profile["email"],
        name: profile["name"],
        # See EMAIL-LINKING POLICY above: no verified-email signal from Meta.
        email_verified: false
      )
    end

    private

    def ensure_configured!
      return if self.class.configured?

      Rails.logger.error("[authentication] facebook is not configured")
      raise Authentication::Error.new(
        "This sign-in method is not available right now.",
        code: :provider_not_configured, status: :service_unavailable
      )
    end

    def debug_token(user_token)
      data = HttpClient.get_json(
        graph_url("debug_token"),
        # App access token. Never logged (HttpClient logs nothing).
        params: {
          input_token: user_token,
          access_token: "#{Authentication.facebook_app_id}|#{Authentication.facebook_app_secret}"
        }
      )["data"]

      unless data.is_a?(Hash) && data["is_valid"] == true
        Rails.logger.warn("[authentication] facebook token rejected: not valid")
        raise invalid_credential
      end

      # The token must have been issued to this application.
      unless data["app_id"].to_s == Authentication.facebook_app_id.to_s
        Rails.logger.warn("[authentication] facebook token rejected: wrong app_id")
        raise invalid_credential
      end

      data
    end

    def fetch_profile(user_token)
      HttpClient.get_json(
        graph_url("me"),
        params: {
          fields: "id,name,email",
          access_token: user_token
        }
      )
    end

    def graph_url(path)
      "https://graph.facebook.com/#{Authentication.facebook_graph_version}/#{path}"
    end

    def invalid_credential
      Authentication::Error.new(
        "The sign-in credential is invalid or has expired. Please try again.",
        code: :invalid_credential, status: :unauthorized
      )
    end
  end
end