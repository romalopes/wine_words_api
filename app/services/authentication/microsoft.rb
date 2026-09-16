require "jwt"

module Authentication
  # Microsoft identity platform (Microsoft Entra ID / personal Microsoft
  # accounts) — OpenID Connect v2.0 endpoint.
  #
  # ---------------------------------------------------------------------------
  # DOCUMENTED TENANT CONFIGURATION (MICROSOFT_TENANT_ID)
  # ---------------------------------------------------------------------------
  # Wine Prediction supports BOTH personal Microsoft accounts and
  # organisational (work/school) Microsoft accounts, so the default and
  # recommended value is "common". The value maps directly onto
  # `/{tenant}/v2.0` in the Microsoft identity platform:
  #
  #   common        (default) personal + organisational  → any tenant
  #   organizations           organisational only        → tenant not the MSA tenant
  #   consumers               personal only               → the MSA tenant only
  #   <tenant-guid-or-domain> a single organisation       → exactly that tenant
  #
  # Only the minimum scopes are requested — `openid email profile`. No Microsoft
  # Graph permission is required or asked for: authentication needs nothing more
  # than the ID token.
  #
  # Identity key: the `sub` claim (stable, pairwise per application + user).
  # AAD also returns `oid`, but `sub` is the documented identity key and is the
  # same value across the personal/organisational boundary, so it is used here.
  class Microsoft < OidcVerifier
    JWKS_URL = "https://login.microsoftonline.com/common/discovery/v2.0/keys".freeze
    ISSUER_HOST = "https://login.microsoftonline.com".freeze
    # Issuers are tenant-specific: https://login.microsoftonline.com/{tid}/v2.0
    ISSUER_PATTERN = %r{\A#{Regexp.escape(ISSUER_HOST)}/[0-9a-fA-F-]{36}/v2\.0\z}
    # The well-known "consumers" (personal Microsoft account) tenant.
    MSA_TENANT_ID = "9188040d-6c67-4c5b-b112-36a304b66dad".freeze

    OAUTH_TENANTS = {
      "common" => nil,
      "organizations" => :organizations,
      "consumers" => :consumers
    }.freeze

    def jwks_url
      JWKS_URL
    end

    # The jwt gem compares issuers with `case/when` (===), so a Regexp gives us
    # the tenant-variable issuer check; the exact tenant is then pinned below
    # using the token's own `tid` claim.
    def accepted_issuers
      concrete_tenant? ? "#{ISSUER_HOST}/#{tenant_id}/v2.0" : ISSUER_PATTERN
    end

    def audience
      Authentication.microsoft_client_id
    end

    def provider_name
      "microsoft"
    end

    private

    def tenant_id
      Authentication.microsoft_tenant_id
    end

    def concrete_tenant?
      !OAUTH_TENANTS.key?(tenant_id)
    end

    def build_claims(payload)
      verify_tenant!(payload)

      Claims.new(
        provider: provider_name,
        provider_uid: payload["sub"],
        email: email_from(payload),
        name: payload["name"],
        email_verified: email_verified?(payload),
        metadata: { tenant: payload["tid"] }
      )
    end

    # Pins the issuer's tenant to the configured policy. "common" accepts any
    # tenant (personal or organisational); "organizations" rejects the personal
    # (MSA) tenant; "consumers" accepts only the MSA tenant.
    def verify_tenant!(payload)
      tid = payload["tid"].to_s
      issuer_tid = payload["iss"].to_s[%r{/([0-9a-fA-F-]{36})/v2\.0\z}, 1]

      # The `tid` claim must agree with the issuer we just verified, otherwise
      # the token's tenant is unauthenticated.
      unless tid.present? && issuer_tid.present? &&
             ActiveSupport::SecurityUtils.secure_compare(tid.downcase, issuer_tid.downcase)
        raise tenant_error("The Microsoft account tenant could not be verified.")
      end

      case OAUTH_TENANTS[tenant_id]
      when :organizations
        raise tenant_error("Only organisational Microsoft accounts are supported.") if tid.casecmp?(MSA_TENANT_ID)
      when :consumers
        raise tenant_error("Only personal Microsoft accounts are supported.") unless tid.casecmp?(MSA_TENANT_ID)
      end
    end

    def tenant_error(message)
      Rails.logger.warn("[authentication] microsoft tenant policy rejected token")
      Authentication::Error.new(message, code: :invalid_tenant, status: :unauthorized)
    end

    # AAD puts the account's address in `email` when it has a mailbox, but
    # `preferred_username` (the UPN / sign-in address) is always present and is
    # directory-authoritative for the tenant we just verified via iss/tid.
    def email_from(payload)
      payload["email"].presence || payload["preferred_username"].presence
    end

    # The address counts as verified when it matches the directory-authoritative
    # UPN, or when the token explicitly asserts email_verified (personal
    # accounts). An `email` claim that disagrees with the UPN is not trusted.
    def email_verified?(payload)
      address = email_from(payload)
      return false if address.blank?

      explicit = payload["email_verified"]
      return true if explicit == true || explicit.to_s == "true"

      preferred = payload["preferred_username"].to_s
      preferred.present? && address.casecmp?(preferred)
    end
  end
end