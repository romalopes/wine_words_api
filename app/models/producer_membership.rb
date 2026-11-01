# Join model linking a User to a Producer with a typed role (issue #191).
#
# Exactly three types exist: owner, manager and contributor. There is no
# follower/viewer row here — following a producer is deliberately out of scope
# and must never be represented by this table.
#
# Owners and managers may edit the producer they belong to; contributors are
# read-only. Global Admin/Editor/Reviewer permissions are unaffected.
class ProducerMembership < ApplicationRecord
  MEMBERSHIP_TYPES = %w[owner manager contributor].freeze
  # Types allowed to edit the associated producer profile.
  EDITABLE_TYPES = %w[owner manager].freeze

  belongs_to :user
  belongs_to :producer
  belongs_to :created_by, class_name: "User", optional: true

  validates :user_id, uniqueness: { scope: :producer_id, message: "is already linked to this producer" }
  validates :membership_type, presence: true
  validates :membership_type,
            inclusion: {
              in: MEMBERSHIP_TYPES,
              allow_blank: true,
              message: "must be owner, manager, or contributor"
            }

  # Scopes for easier querying
  scope :owners, -> { where(membership_type: "owner") }
  scope :managers, -> { where(membership_type: "manager") }
  scope :contributors, -> { where(membership_type: "contributor") }
  # Active management memberships (owner/manager) — the only rows that grant
  # producer-side package management rights (issue #199).
  scope :managing, -> { where(membership_type: EDITABLE_TYPES) }

  # Producer ids the user actively manages (owner/manager). Used by the
  # wine-package policy scope and the WinePackage#managed_by_producer_member?
  # predicate; a contributor/follower never matches.
  def self.managing_producer_ids_for(user)
    return ProducerMembership.none unless user

    where(user_id: user.id).managing.select(:producer_id)
  end

  def owner?
    membership_type == "owner"
  end

  def manager?
    membership_type == "manager"
  end

  def contributor?
    membership_type == "contributor"
  end

  # Owners and managers may edit the producer profile; contributors cannot.
  def can_edit_producer?
    EDITABLE_TYPES.include?(membership_type)
  end
end
