# One message in a Trade package conversation (IDENTITY_206 Phase 8).
#
# Design notes:
#   * This is the CANONICAL conversation store — email is only a notification
#     channel (§1.2 of the trade plan).
#   * `internal_note: true` marks a staff-only line; it is filtered out of every
#     submitter/guest response at the query level (scope :visible_to) so the
#     confidentiality boundary cannot be leaked by a serializer change.
#   * `sender_type` distinguishes submitter/editor/admin lines; the sender is
#     always a User (submitters claim accounts, editors are users).
class WinePackageMessage < ApplicationRecord
  SENDER_TYPES = %w[submitter editor admin].freeze

  belongs_to :wine_package
  # Nullable: guest-token submitters may converse before claiming an account.
  belongs_to :sender, class_name: "User", optional: true

  validates :sender_type, presence: true, inclusion: { in: SENDER_TYPES }
  validates :body, presence: true, length: { maximum: 10_000 }
  validate :sender_present_for_staff

  def sender_present_for_staff
    return unless staff_sender?

    errors.add(:sender, "is required for staff messages") if sender.nil?
  end

  scope :chronological, -> { order(created_at: :asc, id: :asc) }
  scope :internal, -> { where(internal_note: true) }
  scope :shared, -> { where(internal_note: false) }

  # Messages visible to the given viewer: staff (editors/admins) see internal
  # notes; a submitter/guest only ever sees the shared ones.
  scope :visible_to, lambda { |staff|
    staff ? all : shared
  }

  def internal? = internal_note?

  def staff_sender? = sender_type.in?(%w[editor admin])
end