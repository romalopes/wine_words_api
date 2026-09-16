# An external authentication identity belonging to a User.
#
#   User (canonical application identity, one Account, one role set)
#     |
#     +-- UserIdentity provider=google    provider_uid=<Google sub>
#     +-- UserIdentity provider=apple     provider_uid=<Apple sub>
#     +-- UserIdentity provider=microsoft provider_uid=<Microsoft sub>
#     +-- UserIdentity provider=facebook  provider_uid=<Facebook id>
#
# provider_uid — never the email — is the authentication identity key. Emails
# change, Apple can hand back a private relay address, and Facebook may not
# return one at all.
class UserIdentity < ApplicationRecord
  # String-backed enum (matches the Role model convention): the stored column
  # is the human-readable provider name while the enum keys give predicates
  # (identity.google?) and scopes (UserIdentity.microsoft).
  enum :provider, {
    google: "google",
    apple: "apple",
    microsoft: "microsoft",
    facebook: "facebook"
  }, validate: true

  # Display label used by the UI ("Google", "Microsoft", ...).
  PROVIDER_LABELS = {
    "google" => "Google",
    "apple" => "Apple",
    "microsoft" => "Microsoft",
    "facebook" => "Facebook"
  }.freeze

  belongs_to :user

  validates :provider, presence: true
  validates :provider_uid, presence: true
  # Friendly duplicates warning; the unique DB indexes below are the real
  # protection against races between concurrent sign-ins.
  validates :provider_uid, uniqueness: { scope: :provider }, allow_nil: true
  validates :provider, uniqueness: { scope: :user_id }, allow_nil: true

  # Identity lookup used by every provider flow (Case 1 of the resolution
  # rules) and by the account-linking guard.
  scope :for_provider, ->(provider, uid) {
    where(provider: provider, provider_uid: uid)
  }

  def self.find_identity(provider, provider_uid)
    for_provider(provider, provider_uid).first
  end

  def label
    PROVIDER_LABELS[provider.to_s] || provider.to_s.humanize
  end
end
