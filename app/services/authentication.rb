# Social authentication (Google / Apple / Microsoft / Facebook).
#
# Provider credentials are verified *server-side*: React only forwards the
# credential the provider SDK issued, and the backend decides the provider,
# the stable subject identifier, the email and whether that email is verified.
# Nothing the frontend claims about identity is trusted.
#
# Secrets (client secrets, Apple private key, Facebook app secret) live only in
# the environment — on Render for the deployed API — and are never exposed to
# Vite/React. Only public identifiers (client/app ids) exist on the frontend.
module Authentication
  PROVIDERS = %w[google apple microsoft facebook].freeze

  class << self
    # --- Public identifiers -------------------------------------------------

    def google_client_id
      ENV["GOOGLE_CLIENT_ID"].presence
    end

    # Apple "Services ID" (the web client id), e.g. "com.example.winepred.web".
    def apple_client_id
      ENV["APPLE_CLIENT_ID"].presence
    end

    # Required only for the authorization-code exchange (Apple web flow).
    def apple_team_id
      ENV["APPLE_TEAM_ID"].presence
    end

    def apple_key_id
      ENV["APPLE_KEY_ID"].presence
    end

    def apple_private_key
      ENV["APPLE_PRIVATE_KEY"].presence&.then { |key| key.gsub('\n', "\n") }
    end

    def microsoft_client_id
      ENV["MICROSOFT_CLIENT_ID"].presence
    end

    # "common" (personal + organizational, the default), "organizations",
    # "consumers" or a concrete tenant id / domain. See docs/social_authentication.md.
    def microsoft_tenant_id
      ENV["MICROSOFT_TENANT_ID"].presence || "common"
    end

    def facebook_app_id
      ENV["FACEBOOK_APP_ID"].presence
    end

    def facebook_app_secret
      ENV["FACEBOOK_APP_SECRET"].presence
    end

    def facebook_graph_version
      ENV["FACEBOOK_GRAPH_VERSION"].presence || "v21.0"
    end

    # --- Helpers ------------------------------------------------------------

    def verifier_for(provider)
      case provider.to_s
      when "google" then Google
      when "apple" then Apple
      when "microsoft" then Microsoft
      when "facebook" then Facebook
      else
        raise Authentication::Error.new(
          "Unsupported authentication provider.",
          code: :unsupported_provider, status: :bad_request
        )
      end
    end

    def configured?(provider)
      verifier_for(provider).configured?
    end
  end
end
