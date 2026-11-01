# One application activity event on a WinePackage: submitted, accepted,
# rejected, arrival confirmed, review published, withdrawn ... (issue #199).
#
# Design notes:
#   * carrier events are NOT duplicated here — ShipmentTrackingEvent stays the
#     single source of truth for provider history and the timeline projection
#     merges both sources read-only;
#   * `visibility` is the confidentiality boundary: `shared` events are visible
#     to the producer members, `internal` events (editorial decisions) are not;
#   * `idempotency_key` makes provider callbacks / background jobs safe to
#     retry — unique per package;
#   * `actor_id` is nullable for system/carrier-driven events.
class WinePackageEvent < ApplicationRecord
  VISIBILITIES = %w[shared internal].freeze

  belongs_to :wine_package
  belongs_to :actor, class_name: "User", optional: true

  validates :event_type, presence: true, length: { maximum: 64 }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :occurred_at, presence: true
  validates :idempotency_key, length: { maximum: 255 }

  scope :shared, -> { where(visibility: "shared") }
  scope :internal, -> { where(visibility: "internal") }
  scope :chronological, -> { order(occurred_at: :asc, id: :asc) }

  # Events visible to the given viewer: editors/reviewers see everything,
  # producer members only see the shared ones.
  scope :visible_to, lambda { |editorial|
    editorial ? all : shared
  }

  def shared? = visibility == "shared"

  def internal? = visibility == "internal"

  # Idempotent factory. With an `idempotency_key` the same event is recorded
  # only once per package (provider callbacks, retried jobs); without one the
  # event is always recorded. Raises on failure — callers wrap transitions and
  # events in the same transaction so they stay consistent.
  def self.record!(wine_package:, event_type:, actor: nil, visibility: "shared",
                   occurred_at: Time.current, description: nil, metadata: {},
                   idempotency_key: nil)
    attributes = {
      wine_package: wine_package,
      event_type: event_type.to_s,
      actor: actor,
      visibility: visibility,
      occurred_at: occurred_at,
      description: description,
      metadata: metadata || {}
    }

    if idempotency_key.present?
      existing = wine_package.wine_package_events.find_by(idempotency_key: idempotency_key)
      return existing if existing

      begin
        create!(attributes.merge(idempotency_key: idempotency_key))
      rescue ActiveRecord::RecordNotUnique
        # Lost a race with a concurrent callback: return the row that won.
        wine_package.wine_package_events.find_by!(idempotency_key: idempotency_key)
      end
    else
      create!(attributes)
    end
  end
end
