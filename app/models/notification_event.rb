# One domain event that may notify followers: "review X was published",
# "a comment was added to article Y", "producer Z gained a new wine".
#
# Outbox pattern: business operations create an event inside their transaction
# (via Notifications::EventPublisher), a job processes it after commit and
# resolves followers -> deliveries. State:
#
#   pending      processed_at/failed_at both nil (processing_started_at set while running)
#   processed    processed_at present — all deliveries inserted
#   failed       failed_at present — retries exhausted
#
# Idempotency: `idempotency_key` (unique index) makes publishing the same
# logical event twice safe, no matter how many times a callback runs.
#
# `affected_targets` is a JSON snapshot of [(type, id)] pairs captured when the
# event was created — later relationship edits never change an event's audience.
# `metadata` holds only safe display data (names, titles, slugs), never full
# comment/article bodies.
class NotificationEvent < ApplicationRecord
  EVENT_TYPES = %w[
    review.published
    review.updated
    review.comment_created
    article.published
    article.updated
    article.comment_created
    wine.created
    wine.updated
    vintage.created
    vintage.updated
    producer.updated
  ].freeze

  belongs_to :actor, class_name: "User", optional: true
  belongs_to :subject, polymorphic: true, optional: true

  has_many :notifications, dependent: :nullify

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :subject_type, :subject_id, presence: true
  validates :idempotency_key, presence: true, uniqueness: true
  validates :occurred_at, presence: true

  scope :pending, -> { where(processed_at: nil, failed_at: nil) }
  scope :processed, -> { where.not(processed_at: nil) }
  scope :failed, -> { where.not(failed_at: nil) }
  # Events the sweeper should re-enqueue: either the worker started but died
  # mid-processing (stale processing_started_at), or the event was never
  # picked up at all (NULL started_at AND older than the cutoff — fresh
  # never-started events are merely waiting for their worker and must be left
  # alone, otherwise every sweep would double-enqueue normal traffic).
  scope :stale_pending, ->(older_than) do
    pending.where(
      "processing_started_at < :cutoff OR (processing_started_at IS NULL AND created_at < :cutoff)",
      cutoff: older_than
    )
  end

  def pending?
    processed_at.nil? && failed_at.nil?
  end

  def processed?
    processed_at.present?
  end

  def failed?
    failed_at.present?
  end

  # Target snapshot as a normalized list of { type:, id: } hashes.
  def targets
    affected_targets.map { |t| { type: t["type"] || t[:type], id: (t["id"] || t[:id]).to_i } }
  end

  def mark_processing!(at: Time.current)
    update!(processing_started_at: at, attempts: attempts + 1)
  end

  def mark_processed!(at: Time.current)
    update!(processed_at: at, failed_at: nil, last_error: nil)
  end

  def mark_failed!(error, at: Time.current)
    update!(failed_at: at, last_error: "#{error.class}: #{error.message}")
  end
end