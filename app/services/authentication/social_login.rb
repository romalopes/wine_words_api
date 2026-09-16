module Authentication
  # Provider-independent social sign-in / identity linking.
  #
  #   provider credential
  #          ↓  (verified by Authentication::<Provider>, server-side)
  #   verified Claims  { provider, provider_uid, email, email_verified }
  #          ↓
  #   UserIdentity lookup → User (find or create)
  #          ↓
  #   existing Devise/JWT session (the controller calls sign_in)
  #
  # No provider ever gets its own session, its own tokens or its own User or
  # Account. Everything funnels into the same User the email/password flow uses.
  #
  # ---------------------------------------------------------------------------
  # IDENTITY RESOLUTION RULES
  # ---------------------------------------------------------------------------
  # Case 1 — the (provider, provider_uid) identity already exists.
  #          → authenticate its User. Never creates anything. Works even when
  #            the provider stops returning an email (Apple only sends one on
  #            first authorisation).
  #
  # Case 2 — the identity is new, but the *verified* provider email belongs to
  #          an existing User.
  #          → link the identity onto that User, but only when the provider
  #            actually vouches for the address (see AUTO_LINK_BY_EMAIL and
  #            Claims#email_verified?) and it is not an Apple private-relay
  #            address. This is what stops "Continue with Google" from creating
  #            a second account for somebody who already signed up by email.
  #          → otherwise abort with `account_exists`: the person is told to sign
  #            in the way they already can and connect the provider from Account
  #            settings. We never silently attach an external identity to an
  #            account on the strength of an unproven address, and we never
  #            create a duplicate User either.
  #
  # Case 3 — neither the identity nor a matching User exists.
  #          → create User + UserIdentity in one transaction. The User goes
  #            through the *existing* creation workflow, so it automatically
  #            gets the Guest role and FREE subscription from the model hooks,
  #            and its Account is built by the existing Account workflow.
  #
  # Email-verified handling per provider:
  #   google     email_verified claim from Google
  #   microsoft  email == preferred_username, or explicit email_verified
  #   apple      normal address only; private relay is excluded
  #   facebook   no verification signal → never auto-links
  # ---------------------------------------------------------------------------
  class SocialLogin
    # Providers allowed to auto-link onto a User that already has the same
    # verified email address.
    AUTO_LINK_BY_EMAIL = %w[google apple microsoft].freeze

    attr_reader :provider, :credential, :nonce, :user

    # True when the last #sign_in created the User (rather than finding one), so
    # the audit log can say "signed up" instead of "logged in".
    attr_reader :created_user

    # Public sign-in: resolve the credential to a User.
    def self.sign_in(provider:, credential:, nonce: nil)
      new(provider: provider, credential: credential, nonce: nonce).sign_in
    end

    # Linking: attach an additional provider to an already-authenticated User.
    def self.connect(user:, provider:, credential:, nonce: nil)
      new(provider: provider, credential: credential, nonce: nonce, user: user).connect
    end

    def initialize(provider:, credential:, nonce: nil, user: nil)
      @provider = provider.to_s
      @credential = credential
      @nonce = nonce
      @user = user
    end

    # @return [User]
    def sign_in
      claims = verify_credential!

      identity = UserIdentity.find_identity(claims.provider, claims.provider_uid)
      return identity.user if identity # Case 1

      existing = existing_user_for(claims)
      return link_existing_user!(existing, claims) if existing # Case 2

      create_user_and_identity!(claims) # Case 3
    end

    # @return [UserIdentity] the identity now attached to the User
    def connect
      raise ArgumentError, "connect requires an authenticated user" if user.nil?

      claims = verify_credential!

      identity = UserIdentity.find_identity(claims.provider, claims.provider_uid)
      return identity if identity&.user_id == user.id # idempotent

      # Identity hijack guard: an identity that already belongs to someone else
      # is never transferred, silently or otherwise.
      raise identity_taken_error if identity

      create_identity!(user, claims)
    end

    private

    def verify_credential!
      Authentication.verifier_for(provider).verify(credential, nonce: nonce)
    rescue Authentication::Error
      raise
    rescue StandardError => e
      # A verification bug must never leak internals to the client.
      Rails.logger.error("[authentication] #{provider} verification failed: #{e.class}")
      raise Authentication::Error.new(
        "The sign-in credential could not be verified.",
        code: :invalid_credential, status: :unauthorized
      )
    end

    def existing_user_for(claims)
      return nil if claims.email.blank?

      User.find_by(email: claims.email)
    end

    # See the resolution rules above.
    def auto_linkable?(claims)
      AUTO_LINK_BY_EMAIL.include?(claims.provider) &&
        claims.email_verified? &&
        !claims.private_relay_email?
    end

    def link_existing_user!(existing, claims)
      unless auto_linkable?(claims)
        raise Authentication::Error.new(
          "An account already exists for this email address. Sign in the way " \
          "you normally do, then connect #{label_for(claims.provider)} from Account settings.",
          code: :account_exists, status: :conflict
        )
      end

      create_identity!(existing, claims)
      existing
    end

    # Creates the identity on `owner`, tolerating a concurrent request that
    # inserted the same identity first (the unique index is the backstop).
    def create_identity!(owner, claims)
      owner.user_identities.create!(
        provider: claims.provider,
        provider_uid: claims.provider_uid,
        email: claims.email
      )
    rescue ActiveRecord::RecordNotUnique
      retry_or_conflict(owner, claims)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn(
        "[authentication] identity rejected: #{e.record.errors.full_messages.join('; ')}"
      )
      raise identity_taken_error
    end

    def retry_or_conflict(owner, claims)
      existing = UserIdentity.find_identity(claims.provider, claims.provider_uid)
      return existing if existing&.user_id == owner.id

      raise identity_taken_error
    end

    # Case 3 — User and identity are created together, so a failure can never
    # leave an orphaned identity or a half-built account behind.
    def create_user_and_identity!(claims)
      if claims.email.blank?
        raise Authentication::Error.new(
          "Your #{label_for(claims.provider)} account did not share an email " \
          "address. Please use another sign-in method.",
          code: :email_required, status: :unprocessable_entity
        )
      end

      if claims.provider == "apple" && claims.private_relay_email?
        Rails.logger.info("[authentication] apple private relay sign-up (#{claims.email})")
      end

      ActiveRecord::Base.transaction do
        new_user = User.new(
          email: claims.email,
          # Social-only users have no password; the flag suppresses only the
          # on-create password requirement. Role/subscription/Account creation
          # all still run through the existing hooks.
          social_signup: true
        )
        new_user.user_name = unique_user_name_for(claims)
        new_user.save!
        @created_user = true

        create_identity!(new_user, claims)
        new_user
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      # Lost a race against a concurrent sign-in for the same email/identity.
      # Re-resolve rather than surfacing a constraint error to the person.
      Rails.logger.warn("[authentication] social sign-up race recovered: #{e.class}")
      re_resolve(claims)
    end

    def re_resolve(claims)
      @created_user = false

      identity = UserIdentity.find_identity(claims.provider, claims.provider_uid)
      return identity.user if identity

      existing = existing_user_for(claims)
      return existing if existing

      raise Authentication::Error.new(
        "We could not complete the sign-in. Please try again.",
        code: :sign_in_failed, status: :conflict
      )
    end

    # user_name is required, unique (case-insensitively) and restricted to
    # letters/digits/space/dot/dash/underscore with 2..40 characters.
    def unique_user_name_for(claims)
      base = sanitize_user_name(claims.name)
      base ||= sanitize_user_name(claims.email.to_s.split("@").first)
      base = base.to_s[0, 40].strip
      base = "user" if base.length < 2

      candidate = base
      suffix = 0
      while User.exists?([ "LOWER(user_name) = ?", candidate.downcase ])
        suffix += 1
        tag = "_#{suffix}"
        candidate = "#{base[0, 40 - tag.length]}#{tag}"
      end
      candidate
    end

    def sanitize_user_name(value)
      value.to_s.gsub(/[^A-Za-z0-9_.\- ]/, " ").squish.presence
    end

    def identity_taken_error
      Authentication::Error.new(
        "This #{label_for(provider)} account is already connected to another " \
        "account and cannot be linked here.",
        code: :identity_taken, status: :conflict
      )
    end

    def label_for(provider_name)
      UserIdentity::PROVIDER_LABELS[provider_name.to_s] || provider_name.to_s.humanize
    end
  end
end