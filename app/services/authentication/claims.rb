module Authentication
  # Provider-independent result of verifying a provider credential.
  #
  # This is the *only* shape the rest of the application sees, which keeps
  # Google/Apple/Microsoft/Facebook differences out of the User model and out
  # of the resolution/linking rules.
  class Claims
    # Apple "Hide My Email" relay addresses. They are valid, deliverable
    # addresses but belong to Apple rather than to the person, so they are
    # never used to auto-link an existing account by email.
    PRIVATE_RELAY_DOMAINS = [ "privaterelay.appleid.com" ].freeze

    attr_reader :provider, :provider_uid, :email, :name, :metadata

    def initialize(provider:, provider_uid:, email: nil, name: nil,
                   email_verified: false, metadata: {})
      @provider = provider.to_s
      @provider_uid = provider_uid.to_s
      # Emails are stored/compared downcased, matching Devise's
      # case_insensitive_keys configuration.
      @email = email.to_s.strip.downcase.presence
      @name = name.to_s.strip.presence
      @email_verified = !!email_verified
      @metadata = metadata || {}
    end

    # True only when the *provider* asserted the address is verified (Google's
    # email_verified claim) or when the documented per-provider policy accepts
    # it. Drives the account-linking rules — never trust the frontend for this.
    def email_verified?
      @email_verified
    end

    def private_relay_email?
      return false if email.blank?

      PRIVATE_RELAY_DOMAINS.any? { |domain| email.end_with?("@#{domain}") }
    end

    def to_h
      {
        provider: provider,
        provider_uid: provider_uid,
        email: email,
        name: name,
        email_verified: email_verified?
      }
    end
  end
end