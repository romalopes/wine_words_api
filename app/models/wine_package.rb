# A WinePackage is the unit of work behind the reviewing workflow: a producer
# sends (or announces) one or more wines to Wine Words and a reviewer is
# responsible for reviewing every item flagged as `review_requested`.
#
# Design notes:
#   * `status` and `source` are string-backed enums — the codebase convention
#     (see Review#status, Producer#producer_type, UserSubscription#status).
#     The enum gives predicates/scopes; WinePackage adds the transition guard
#     below because Rails enums alone do not enforce a legal workflow.
#   * There is no Project association: no Project model exists in the app, so
#     adding the FK would only create a dangling reference.
#   * Arrival starts the clock: `review_deadline` defaults to one calendar
#     month after `arrived_at` and is NEVER overwritten once set.
class WinePackage < ApplicationRecord
  include Imageable

  # Raised when a caller attempts a transition the workflow does not allow.
  class InvalidTransition < StandardError; end

  STATUSES = %w[
    draft requested accepted rejected announced in_transit arrived reviewing
    completed cancelled
  ].freeze

  SOURCES = %w[manual unexpected producer_request producer_announcement].freeze

  # Statuses from which no further progress is expected. They are excluded
  # from "active" queries (deadline reminders must skip them).
  TERMINAL_STATUSES = %w[completed cancelled rejected].freeze

  # The only legal moves in the workflow. Keys are the *current* status and the
  # values are the reachable statuses. Terminal statuses are reopenable to
  # `draft` (cancelled) or `reviewing` (completed) so a mistake is reversible.
  VALID_TRANSITIONS = {
    "draft" => %w[requested announced arrived cancelled],
    # A requested package may be accepted/rejected, but wines can also simply
    # turn up (or be shipped) before the paperwork is settled.
    "requested" => %w[accepted rejected announced in_transit arrived cancelled],
    "accepted" => %w[announced in_transit arrived cancelled],
    "rejected" => %w[],
    "announced" => %w[in_transit arrived cancelled],
    "in_transit" => %w[arrived cancelled],
    "arrived" => %w[reviewing completed cancelled],
    "reviewing" => %w[completed arrived cancelled],
    "completed" => %w[reviewing],
    "cancelled" => %w[draft]
  }.freeze

  # One calendar month — Date#>> handles year rollover (2026-12-15 => 2027-01-15).
  REVIEW_WINDOW_MONTHS = 1

  belongs_to :producer
  # The reviewer responsible for the package. Any signed-in User may review;
  # the "Reviewer" role is not required for domain ownership.
  belongs_to :reviewer, class_name: "User", optional: true
  # Who recorded the package (audit; may differ from the reviewer).
  belongs_to :created_by, class_name: "User", optional: true
  # The producer-side requester (issue #199): the owner/manager member who
  # submitted the package on the producer's behalf.
  belongs_to :requested_by, class_name: "User", optional: true
  belongs_to :accepted_by, class_name: "User", optional: true
  belongs_to :rejected_by, class_name: "User", optional: true

  has_many :wine_package_items, dependent: :destroy
  # Only items explicitly marked as needing a review block completion.
  has_many :review_requested_items,
           -> { where(review_requested: true) },
           class_name: "WinePackageItem"
  has_many :vintages, through: :wine_package_items
  has_many :shipment_tracking_events, dependent: :destroy
  has_one :shipment_tracking, dependent: :destroy
  has_many :notifications, dependent: :destroy
  # Typed attachments (bottle photos, postal receipts, ...) and the
  # application activity timeline (issue #199).
  has_many :wine_package_attachments, dependent: :destroy
  has_many :wine_package_events, dependent: :destroy

  accepts_nested_attributes_for :wine_package_items,
                                allow_destroy: true,
                                reject_if: :all_blank

  enum :status, {
    draft: "draft",
    requested: "requested",
    accepted: "accepted",
    rejected: "rejected",
    announced: "announced",
    in_transit: "in_transit",
    arrived: "arrived",
    reviewing: "reviewing",
    completed: "completed",
    cancelled: "cancelled"
  }, default: :draft, validate: true

  enum :source, {
    manual: "manual",
    unexpected: "unexpected",
    producer_request: "producer_request",
    producer_announcement: "producer_announcement"
  }, default: :manual, validate: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :rejection_reason, presence: true, if: :rejected?
  validate :review_deadline_cannot_precede_arrival

  scope :active, -> { where.not(status: TERMINAL_STATUSES) }
  scope :overdue, lambda {
    active.where.not(review_deadline: nil).where(review_deadline: ...Date.current)
  }
  scope :with_upcoming_deadline, lambda { |on_or_after = Date.current|
    active.where.not(review_deadline: nil).where(review_deadline: on_or_after..)
  }
  scope :requiring_reviews, lambda {
    where(status: %w[arrived reviewing])
      .joins(:wine_package_items)
      .where(wine_package_items: { review_requested: true })
      .distinct
  }
  scope :by_recency, -> { order(created_at: :desc) }
  # Packages the user manages as an active owner/manager member of their
  # producer (issue #199). A mere follower or contributor never matches.
  scope :managed_by_producer_member, lambda { |user|
    return none unless user

    where(producer_id: ProducerMembership.managing_producer_ids_for(user))
  }

  # Package fields a producer member may edit on their own draft (issue #199 §6).
  # `notes` remains editorial-only and `internal_notes` is never
  # producer-writable or producer-readable.
  PRODUCER_EDITABLE_FIELDS = %w[
    producer_reference producer_notes shipping_notes expected_at
  ].freeze

  # Convenience alias for the items collection.
  def items
    wine_package_items
  end

  # ---- Workflow ---------------------------------------------------------

  # True when `new_status` is reachable from the current status. A no-op
  # transition to the current status is reported as false (the workflow
  # methods below treat same-status calls as idempotent).
  def can_transition_to?(new_status)
    new_status = new_status.to_s
    return false unless self.class.statuses.key?(new_status)

    VALID_TRANSITIONS.fetch(status, []).include?(new_status)
  end

  # Moves the package to `new_status` and persists it.
  #
  # Raises WinePackage::InvalidTransition for a move the workflow forbids.
  # Transitioning to the current status is an idempotent no-op: any pending
  # attribute changes (e.g. a just-set arrived_at) are still saved.
  #
  # The status change and its activity-timeline event (WinePackageEvent, issue
  # #199) land in the same transaction so they can never drift apart. `actor:`
  # is the signed-in user who caused the move; transitions without one (system,
  # console, carrier callbacks) stay actor-nil.
  def transition_to!(new_status, actor: nil)
    new_status = new_status.to_s
    unless self.class.statuses.key?(new_status)
      raise ArgumentError, "unknown status: #{new_status}"
    end

    if status == new_status
      save! if changed?
      return true
    end

    unless can_transition_to?(new_status)
      raise InvalidTransition, "cannot transition from #{status.inspect} to #{new_status.inspect}"
    end

    transaction do
      update!(status: new_status)
      WinePackageEvent.record!(
        wine_package: self,
        event_type: new_status,
        actor: actor || transition_actor_for(new_status),
        occurred_at: Time.current
      )
    end
    true
  end

  # Best-effort provenance for the timeline event: whoever the workflow
  # already recorded for this step.
  def transition_actor_for(new_status)
    case new_status
    when "accepted" then accepted_by
    when "rejected" then rejected_by
    when "requested" then requested_by || created_by
    end
  end

  # Producer asked Wine Words to review these wines.
  def request!(at: Time.current, actor: nil)
    self.requested_at ||= at
    self.requested_by ||= actor if actor
    transition_to!("requested", actor: actor || requested_by)
  end

  def accept!(by:, at: Time.current)
    self.accepted_by = by
    self.accepted_at ||= at
    self.rejected_by = nil
    self.rejected_at = nil
    self.rejection_reason = nil
    transition_to!("accepted", actor: by)
  end

  def reject!(by:, reason: nil, at: Time.current)
    self.rejected_by = by
    self.rejected_at ||= at
    self.rejection_reason = reason if reason.present?
    transition_to!("rejected", actor: by)
  end

  def mark_in_transit!(at: Time.current, actor: nil)
    transition_to!("in_transit", actor: actor)
  end

  # Physical arrival. Starts the review clock: `arrived_at` defaults to now and
  # `review_deadline` defaults to one calendar month later. Both keep any
  # explicitly supplied value (||=), so a manually set deadline is preserved.
  def mark_arrived!(at: Time.current, actor: nil)
    self.arrived_at ||= at
    self.review_deadline ||= default_review_deadline
    transition_to!("arrived", actor: actor)
  end

  def start_reviewing!(actor: nil)
    transition_to!("reviewing", actor: actor)
  end

  # Explicit completion — a reviewer may complete a package even when some
  # review_requested items have no published review yet.
  def mark_completed!(at: Time.current, actor: nil)
    self.reviewed_at ||= at
    transition_to!("completed", actor: actor)
  end

  # Undo an accidental completion. Reopening clears the automatic-completion
  # provenance: whatever happens next is a fresh workflow decision.
  def reopen!(actor: nil)
    self.auto_completed = false
    transition_to!("reviewing", actor: actor)
  end

  def cancel!(actor: nil)
    transition_to!("cancelled", actor: actor)
  end

  # ---- Producer-managed request flow (issue #199) ------------------------

  # Submits a producer-managed draft as a review request. A draft must carry
  # at least one wine line; the requester is recorded and the "requested"
  # event lands in the timeline (recorded by the transition itself).
  def submit_request!(at: Time.current, actor: nil)
    raise InvalidTransition, "only a draft package can be submitted" unless draft?
    raise InvalidTransition, "add at least one wine to the package before submitting" if wine_package_items.empty?

    self.submitted_at ||= at
    self.requested_by ||= actor if actor
    request!(at: at, actor: actor || requested_by)
    true
  end

  # Withdraws a pending (requested) producer request. Cancellation is the only
  # legal move out of "requested" besides the editorial decisions, and a
  # cancelled package may be reopened to draft later (existing workflow).
  def withdraw!(by: nil, at: Time.current)
    raise InvalidTransition, "only a pending request can be withdrawn" unless requested?

    transaction do
      WinePackageEvent.record!(
        wine_package: self, event_type: "withdrawn", actor: by, occurred_at: at
      )
      cancel!(actor: by)
    end
    true
  end

  # Is this user an active owner/manager member of the package's producer?
  def managed_by_producer_member?(user)
    return false unless user

    ProducerMembership.managing_producer_ids_for(user).include?(producer_id)
  end

  # ---- Review progress --------------------------------------------------

  # One calendar month after arrival (nil until the package has arrived).
  def default_review_deadline
    return nil if arrived_at.blank?

    arrived_at.to_date >> REVIEW_WINDOW_MONTHS
  end

  def reviewed_items
    review_requested_items.includes(:review).select(&:reviewed?)
  end

  # The only items that block completion: review_requested and not yet
  # covered by a published review. Non-review wines never block.
  def pending_review_items
    review_requested_items.includes(:review).reject(&:reviewed?)
  end

  def pending_review_count
    pending_review_items.size
  end

  def reviews_complete?
    pending_review_count.zero?
  end

  # 100% when nothing was requested — nothing is left to block.
  def review_progress_percent
    requested = review_requested_items.size
    return 100 if requested.zero?

    ((reviewed_items.size.to_f / requested) * 100).round
  end

  def review_progress
    requested = review_requested_items.size
    reviewed = reviewed_items.size

    {
      requested: requested,
      reviewed: reviewed,
      pending: requested - reviewed,
      percent: review_progress_percent
    }
  end

  # Finished business is never overdue — this mirrors the `overdue` scope, which
  # only considers active packages, so the predicate and the scope always agree.
  def overdue?
    return false if completed? || cancelled? || rejected?

    review_deadline.present? && review_deadline < Date.current
  end

  # Negative when the deadline has already passed.
  def days_until_deadline
    return nil if review_deadline.blank?

    (review_deadline - Date.current).to_i
  end

  private

  def review_deadline_cannot_precede_arrival
    return if review_deadline.blank? || arrived_at.blank?
    return if review_deadline >= arrived_at.to_date

    errors.add(:review_deadline, "cannot be earlier than the arrival date")
  end
end
