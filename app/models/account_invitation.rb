class AccountInvitation < ApplicationRecord
  VALIDITY_PERIOD = 7.days
  TOKEN_BYTES = 32

  belongs_to :user
  belongs_to :invited_by, class_name: "User", optional: true
  belongs_to :revoked_by, class_name: "User", optional: true

  enum :status, {
    pending: "pending",
    sent: "sent",
    accepted: "accepted",
    revoked: "revoked"
  }

  before_validation :normalize_email

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validate :email_matches_user

  scope :usable, -> { where(status: %w[pending sent]).where("expires_at > ?", Time.current) }

  class << self
    def digest_token(raw_token)
      Digest::SHA256.hexdigest(raw_token)
    end

    # Creates a new invitation while revoking every previously usable invitation
    # for the account under a user row lock. The raw token is returned once to the
    # caller and is never persisted.
    def issue!(user:, email:, invited_by: nil, expires_at: VALIDITY_PERIOD.from_now)
      invitation = nil
      raw_token = nil

      transaction do
        user.lock!
        unless user.unclaimed? && !user.deleted?
          user.errors.add(:account_status, "must be unclaimed and not deleted to receive an invitation")
          raise ActiveRecord::RecordInvalid, user
        end

        raw_token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
        user.account_invitations.usable.update_all(status: "revoked", revoked_at: Time.current,
                                                   revoked_by_id: invited_by&.id, updated_at: Time.current)
        invitation = create!(
          user: user,
          invited_by: invited_by,
          email: email,
          token_digest: digest_token(raw_token),
          expires_at: expires_at
        )
      end

      [ invitation, raw_token ]
    end

    def find_usable_by_token(raw_token)
      return nil if raw_token.blank?

      usable.find_by(token_digest: digest_token(raw_token))
    end
  end

  def usable?
    (pending? || sent?) && expires_at.future?
  end

  def expired?
    expires_at <= Time.current
  end

  def revoke!(actor: nil)
    with_lock do
      return false unless usable?

      update!(status: "revoked", revoked_at: Time.current, revoked_by: actor)
    end
    true
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end

  def email_matches_user
    return if email.blank? || user.blank? || user.email.blank?
    return if email.casecmp?(user.email)

    errors.add(:email, "must match the user's current email")
  end
end
