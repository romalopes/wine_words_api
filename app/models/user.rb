class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  has_many :reviews, dependent: :destroy
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :billing_customers, dependent: :destroy
  has_many :subscription_changes, dependent: :restrict_with_error
  belongs_to :subscription, optional: true
  has_many :user_subscriptions, dependent: :destroy
  has_one :account, dependent: :destroy

  # Wine packages owned by this user as the responsible reviewer, and packages
  # this user recorded. Both are nullable on the package, so destroying a user
  # detaches the history instead of deleting it.
  has_many :wine_packages, foreign_key: :reviewer_id, dependent: :nullify
  has_many :created_wine_packages, class_name: "WinePackage",
                                   foreign_key: :created_by_id,
                                   dependent: :nullify
  has_many :notifications, foreign_key: :recipient_id, dependent: :destroy

  # External authentication identities (Google / Apple / Microsoft / Facebook).
  # The User stays the canonical identity and keeps exactly one Account, one
  # role set and one subscription no matter how many providers are connected.
  has_many :user_identities, dependent: :destroy

  # Transient flag set when a User is created exclusively through a social
  # provider. Such a user has no password at all (rather than an unknowable
  # random one), so :validatable must not demand one on create. It is never
  # persisted and defaults to false, leaving email/password sign-up untouched.
  attr_accessor :social_signup

  # user_name is the application username/handle. It is independent of the
  # real name stored on Account (first_name/last_name) and never synced from it.
  validates :user_name,
            presence: true,
            length: { in: 2..40 },
            uniqueness: { case_sensitive: false },
            format: { with: /\A[A-Za-z0-9_.\- ]+\z/, message: "only letters, digits, spaces, dots, dashes and underscores" }

  # Every new user starts with the "Guest" role and the FREE subscription
  # unless roles were explicitly assigned (e.g. seeded admins).
  after_create :assign_default_role
  after_create :assign_default_subscription

  # Base access roles are mutually exclusive and controlled by the subscription:
  #   FREE subscription  -> "Guest"
  #   any paid subscription -> "Reader"
  # Privileged roles (Reviewer, Admin, Editor) are independent of the
  # subscription and are NEVER touched by subscription changes.
  BASE_ROLES = ["Guest", "Reader"].freeze

  def role?(key)
    roles.exists?(name: Role.names[key] || key)
  end


  def admin?
    role?(:admin)
  end

  # ---------------------------------------------------------------------------
  # Email verification (see EmailVerificationService / EmailVerification).
  # A user is "pending" while they have an unconsumed verification token.
  # Pending users cannot sign in (feature on) and are locked out entirely once
  # the verification window (EmailVerification.expiration) has passed.
  # ---------------------------------------------------------------------------

  def email_verified?
    email_verified_at.present?
  end

  def email_verification_pending?
    !email_verified? && email_verification_token_digest.present?
  end

  # When the current verification link stops working. nil if nothing pending.
  def email_verification_expires_at
    return nil if email_verification_sent_at.blank?

    email_verification_sent_at + EmailVerification.expiration
  end

  def email_verification_expired?
    return false unless email_verification_pending?

    expires_at = email_verification_expires_at
    expires_at.present? && expires_at < Time.current
  end

  # Generates a fresh one-time token (the raw value is returned once, for the
  # mailer — only its digest is stored), invalidating any previous token and
  # resetting the verification window.
  def generate_email_verification_token!
    raw_token = SecureRandom.urlsafe_base64(32)
    update!(
      email_verification_token_digest: EmailVerificationService.digest_token(raw_token),
      email_verification_sent_at: Time.current,
      email_verified_at: nil
    )
    raw_token
  end

  # Consumes the raw token clicked from the email: marks the address verified
  # and clears the token state. Returns the user on success, nil when the token
  # does not match or the window has expired (caller renders a generic error).
  def consume_email_verification_token(raw_token)
    return nil if raw_token.blank?
    return nil if email_verification_expired?
    return nil if email_verification_token_digest != EmailVerificationService.digest_token(raw_token)

    update!(
      email_verified_at: Time.current,
      email_verification_token_digest: nil,
      email_verification_sent_at: nil
    )
    self
  end

  # "super_admin" is the platform-wide administrator role used to gate
  # sensitive views (e.g. Users & Roles). The system currently has a single
  # "Admin" tier, so super_admin? is an alias for admin?. If a separate
  # SuperAdmin role is ever introduced, change this to role?(:super_admin).
  def super_admin?
    admin?
  end

  def reviewer?
    role?(:reviewer)
  end

  # Admins and Editors: the tier that also sees and manages everything
  # (including every wine package, see WinePackageAuthorizable).
  def catalogue_manager?
    admin? || role?(:editor)
  end

  # Admins, Editors and Reviewers may manage the catalogue — wines, vintages,
  # producers, categories and the rest. Anywhere a Reviewer is allowed, an
  # Editor is allowed too: a Reviewer authenticates the wines we review, so they
  # are content managers. Note this is deliberately WIDER than
  # catalogue_manager? (it includes Reviewers).
  def wine_manager?
    catalogue_manager? || reviewer?
  end

  def role_names
    roles.map { |r| Role.names[r.name.to_s] || r.name.to_s }.sort
  end

  def jwt_payload
    { user_name: user_name, roles: role_names }
  end

  # ---- Authentication methods -------------------------------------------
  # A User may authenticate with email/password and/or any number of social
  # providers. These helpers keep that knowledge on the User so the linking
  # rules ("always keep at least one way to sign in") stay provider-agnostic.

  # True when the account can sign in with an email/password pair. Users
  # created purely through a social provider have no encrypted password.
  def password_authentication?
    encrypted_password.present?
  end

  def social_authentication?
    user_identities.exists?
  end

  def authentication_method_count
    (password_authentication? ? 1 : 0) + user_identities.count
  end

  # A user who can only sign in through social providers and holds no password.
  def social_only?
    !password_authentication? && social_authentication?
  end

  # Devise :validatable requires a password whenever the record is new. Social
  # sign-up has no password to give, so it opts out — but only for that one
  # creation via the transient social_signup flag. Existing email/password
  # users (and password changes) keep full password validation.
  def password_required?
    return false if social_signup

    super
  end

  # Apply a subscription to this user. Switches the base access role
  # (Guest <-> Reader) while preserving privileged roles (Reviewer, Admin,
  # Editor). Records subscription history via user_subscriptions.
  #
  # Paid -> paid upgrades change features only and skip role writes entirely.
  #
  # Accepts optional billing metadata so a subscription can be applied from a
  # billing provider (e.g. Stripe) as well as manually by a Admin. The
  # role logic stays provider-independent.
  #
  # When allow_downgrade is false (default), raises Billing::Error if the
  # new subscription has a lower price than the current one. Pass
  # allow_downgrade: true to bypass this check (e.g. for cancellation
  # fallback to the FREE plan or Stripe-confirmed downgrades).
  #
  # Period boundaries: when current_period_start / current_period_end are
  # given (from Stripe subscription data) they are persisted so local history
  # stays aligned with the provider's billing anchors instead of Time.current.
  # The previous row's ended_at uses the captured previous period end, falling
  # back to Time.current for non-provider (manual) changes.
  def apply_subscription!(
    new_subscription,
    billing_provider: "manual",
    provider_subscription_id: nil,
    current_period_start: nil,
    current_period_end: nil,
    previous_period_end: nil,
    allow_downgrade: false
  )
    return if new_subscription.nil?

    if !allow_downgrade && subscription.present? && new_subscription.lower_price_than?(subscription)
      raise Billing::Error, "Downgrade to a lower-priced plan is not allowed."
    end

    Rails.logger.info "[User] apply_subscription! called: user_id=#{id} subscription_id=#{new_subscription.id} billing_provider=#{billing_provider} provider_subscription_id=#{provider_subscription_id} allow_downgrade=#{allow_downgrade}"

    new_base = new_subscription.free? ? "Guest" : "Reader"
    current_base = roles.where(name: BASE_ROLES).pick(:name)
    changing_base = (current_base != new_base)
    Rails.logger.info "[User] apply_subscription!: current_base=#{current_base} new_base=#{new_base} changing_base=#{changing_base}"

    transaction do
      previous_end = previous_period_end
      previous_end ||= user_subscriptions.current.order(:started_at).first&.current_period_end
      user_subscriptions.current.update_all(ended_at: previous_end || Time.current)
      Rails.logger.info "[User] apply_subscription!: ended previous subscriptions for user #{id} (ended_at=#{previous_end || Time.current})"

      new_us = user_subscriptions.create!(
        subscription: new_subscription,
        started_at: current_period_start || Time.current,
        status: :active,
        billing_provider: billing_provider,
        provider_subscription_id: provider_subscription_id,
        current_period_start: current_period_start,
        current_period_end: current_period_end
      )
      Rails.logger.info "[User] apply_subscription!: created user_subscription id=#{new_us.id} for user #{id}"

      if changing_base
        roles.delete(Role.where(name: BASE_ROLES))
        roles << Role.find_or_create_by!(name: new_base)
        Rails.logger.info "[User] apply_subscription!: changed base role from #{current_base} to #{new_base}"
      end

      update!(subscription: new_subscription)
    end

    Rails.logger.info "[User] apply_subscription! completed: user #{id} now on subscription #{new_subscription.id}"
  end

  private

  def assign_default_role
    roles << Role.find_or_create_by!(name: "Guest") if roles.empty?
  end

  def assign_default_subscription
    default_sub = Subscription.default
    return unless default_sub
    return if subscription_id.present?

    update_column(:subscription_id, default_sub.id)
    user_subscriptions.create!(subscription: default_sub, started_at: Time.current, status: :active)
  end
end
